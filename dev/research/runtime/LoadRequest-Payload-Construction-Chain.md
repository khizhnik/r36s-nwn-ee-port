# Goal
Identify who constructs the payload passed into `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`, then reverse the chain back to the native Load button handler.

This is separate from the earlier selection/preview lifecycle:

- `CPanelLoadSave::HandleSelectSaveGame`
- `CExoResMan::AddResourceDirectory`
- `CNWPortrait::ReplacePortraitTexture`

That lifecycle explains row selection and preview refresh, but not the actual load request payload.

# Direct callers of `CClientExoApp::SendLoadGameRequest`

Static disassembly shows two direct callers of the public client facade:

| Caller | Address | Responsibility | What it prepares | Reads UI state / save list / selected entry? | Evidence |
|---|---:|---|---|---|---|
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6fa1d0` | Primary panel-layer load request builder | Selected save index, save name, module-related strings, and the trailing `int` flag before handing off to the client layer | Yes. It reads the selected index from panel state and resolves metadata through `CSaveGameList` | Disassembly shows it loads the selected index from panel state, calls `CSaveGameList::GetSaveGameName(int)`, calls `CSaveGameList::GetSaveGameFileInfo(int)` twice, then sets up the call to `CClientExoApp::SendLoadGameRequest(...)` |
| `CPanelLoadGame::OnConnectServerStatusPanelExit(int)` | `0x6f7fa0` | Alternate panel/status exit path that also dispatches the load request | Rebuilds the same load payload from panel/save-list state and then calls the client layer | Yes. It reads the selected save index and save list metadata during its exit handling | Disassembly shows it resolves the selected index, calls `CSaveGameList::GetSaveGameName(int)`, calls `CSaveGameList::GetSaveGameFileInfo(int)` twice, and then calls `CClientExoApp::SendLoadGameRequest(...)` at `0x6f81bb` |

The public client facade itself is thin:

- `CClientExoApp::SendLoadGameRequest(...)` at `0x637960` simply forwards to `CClientExoAppInternal::SendLoadGameRequest(...)`
- `CClientExoAppInternal::SendLoadGameRequest(...)` at `0x63c610` then tail-jumps to `CNWCMessage::SendPlayerToServerModule_LoadGame(...)`

# Reverse call chain

There are two relevant upstream routes into the same client request boundary.

## Native Load button path

1. `CPanelLoadGame::HandleOkButton()`
2. `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)`
3. `CPanelLoadGame::SendLoadGameRequest()`
4. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
5. `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
6. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
7. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

The key static edge here is:

- `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)` tail-jumps to `CPanelLoadGame::SendLoadGameRequest()` when the exit code equals `1`

## Alternate status-panel path

1. `CPanelLoadGame::OnConnectServerStatusPanelExit(int)`
2. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
3. `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
4. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
5. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

This alternate caller is not the primary button path, but it proves the same payload boundary can be reached from another panel-state transition.

# Argument construction

The payload observed at runtime in `CClientExoApp::SendLoadGameRequest(...)` was:

- `arg1` ≈ save slot / numeric save discriminator
- `s1` = save name / save folder suffix
- `s2` = module name
- `arg4` = flags; observed as `0`

Correlating runtime values with the harness save tree showed:

- `arg1 = 4`, `s1 = "888"`, `s2 = "The Prelude"`
- `arg1 = 2`, `s1 = "23w"`, `s2 = "The Prelude"`

The matching harness save directories are:

- `dev/pc/userdir/saves/000004 - 888`
- `dev/pc/userdir/saves/000002 - 23w`

That means the payload is assembled from the selected save entry and its metadata before it reaches the client facade.

# Earliest joint availability

The earliest function where the three important load-request fields first become available together is:

`CPanelLoadGame::SendLoadGameRequest()`

Why:

- it reads the selected save index from panel state
- it resolves save metadata through `CSaveGameList`
- it constructs the string payload that later appears at `CClientExoApp::SendLoadGameRequest(...)`

`CPanelLoadGame::OnConnectServerStatusPanelExit(int)` is a second constructor path, but it is an alternate route rather than the earliest panel-level source.

# Call graph

```text
Native Load button
    ↓
CPanelLoadGame::HandleOkButton()
    ↓
CPanelLoadGame::HandleIngameOkCancelPanelExit(1)
    ↓
CPanelLoadGame::SendLoadGameRequest()
    ↓
CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)
    ↓
CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)
    ↓
CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)
    ↓
CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)
```

```text
Alternate panel/status path
    ↓
CPanelLoadGame::OnConnectServerStatusPanelExit(int)
    ↓
CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)
    ↓
CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)
    ↓
CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)
    ↓
CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)
```

# Implications for the custom launcher

The custom launcher does not need to reimplement the server-side load logic.

It needs to reproduce, or invoke, the native panel-layer state and request assembly that feed:

`CPanelLoadGame::SendLoadGameRequest()`

The current wrapper already tracks the same conceptual fields:

- selected save index
- save folder / name
- module name

That makes the wrapper close to the native payload shape, but the native construction path still matters because it also involves the panel state and save-list lookup.

# Conclusion

The payload is not built in `CClientExoApp::SendLoadGameRequest(...)`; that function is a thin handoff.

The primary payload-construction function is:

`CPanelLoadGame::SendLoadGameRequest()`

with `CPanelLoadGame::OnConnectServerStatusPanelExit(int)` as an alternate caller that also assembles and forwards the same kind of request.
