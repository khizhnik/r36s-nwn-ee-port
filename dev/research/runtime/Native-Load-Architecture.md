# Goal
This document closes the reverse-engineering phase for native save loading and becomes the technical basis for bridge implementation.

The native save-load path is now understood well enough to stop searching for additional reverse-engineering targets and instead focus on how to invoke the existing native pipeline safely from the custom NUI launcher.

# Final confirmed native load chain
```text
CreateLoadGamePanel()
→ PostAttachmentInitialize()
→ PopulateListWithSaveDirContents()
→ CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
→ CPanelLoadGame::SendLoadGameRequest()
→ CClientExoApp::SendLoadGameRequest(...)
→ CClientExoAppInternal::SendLoadGameRequest(...)
→ CNWCMessage::SendPlayerToServerModule_LoadGame(...)
→ CServerExoApp::LoadGame(...)
```

# Evidence summary

## perf uprobes
Confirmed by passive perf tracing:
- `CPanelLoadSave::HandleSelectSaveGame(int)` fires on row selection
- `CExoResMan::AddResourceDirectory(...)` fires during selection refresh
- `CNWPortrait::ReplacePortraitTexture(...)` fires during selection refresh
- `CPanelLoadGame::HandleOkButton()` / `CPanelLoadGame::SendLoadGameRequest()` / client/network/server load path all fire on the real load request path

## bpftrace runtime argument capture
Confirmed by passive `bpftrace` on `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`:
- register mapping is correct on x86_64 SysV
- `CExoString` layout is confirmed
- the payload values were captured and correlated with real save files

## static disassembly
Confirmed by disassembly:
- `CreateLoadGamePanel()` creates the live `CPanelLoadGame`
- `PostAttachmentInitialize()` builds the panel and performs first selection
- `BuildButtonList()` tail-jumps to `PopulateListWithSaveDirContents()`
- `CPanelLoadGame::SendLoadGameRequest()` reads the selected index from panel state and constructs the request payload
- `CGuiTabSet::SelectTab(N)` is the native selection-state writer

## filesystem payload correlation
Confirmed by correlating runtime payloads with harness save directories/files:
- `s1` matches save name / folder suffix
- `s2` matches module name
- `arg1` matches the numeric save slot / prefix-like discriminator
- `arg4` is flags and was observed as `0`

# Selection lifecycle

Native selection lifecycle:
```text
CreateLoadGamePanel()
→ CPanelLoadGame::PostAttachmentInitialize()
→ CPanelLoadSave::PostAttachmentInitialize(int)
→ CPanelLoadGame::BuildButtonList()
→ CPanelLoadSave::PopulateListWithSaveDirContents()
```

First selection initialization:
```text
CGuiTabSet::SelectTab(0)
→ CPanelLoadSave::HandleSelectSaveGame(0)
```

Arbitrary selection:
```text
CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
```

Native load request:
```text
CPanelLoadGame::SendLoadGameRequest()
```

Confirmed runtime validation shows:
- `SelectTab(N)` updates the active selection state
- `HandleSelectSaveGame(N)` follows immediately after selection changes
- `SendLoadGameRequest()` uses the final selected index

# Payload model

Confirmed payload observed at `CClientExoApp::SendLoadGameRequest(...)`:
- `arg1` = numeric save slot / prefix-like discriminator
- `s1` = save name / folder suffix
- `s2` = module name
- `arg4` = flags, observed as `0`

Observed examples:
- `arg1=4`, `s1="888"`, `s2="The Prelude"`
- `arg1=2`, `s1="23w"`, `s2="The Prelude"`

# CExoString layout

Runtime-confirmed `CExoString` layout:
- offset `0x0` = `char*`
- offset `0x8` = `uint32 len`
- offset `0xC` = `uint32 cap/aux`

This layout was validated with raw byte inspection and fixed-length string decoding via `bpftrace`.

# Panel state model

Confirmed panel state:
- live `CPanelLoadGame` is owned by `CClientExoAppInternal+0xa0`
- selected index is stored in the embedded `CGuiTabSet` current field
- `CPanelLoadGame+0x960` = current selected index
- `CPanelLoadGame+0x13d0` = embedded `CSaveGameList`
- `CPanelLoadGame+0xd50` = save-list translation table

Relevant additional state:
- `CPanelLoadGame+0x948` = embedded `CGuiTabSet`
- `CPanelLoadGame+0x950` = registered selection callback (`HandleSelectSaveGame`)
- `CPanelLoadGame+0x958` = auxiliary callback/state slot initialized to zero

# Rejected / corrected hypotheses

- The `sleep 1d` perf model was wrong; the correct model is `perf record -p <real nwmain PID>`
- The selection lifecycle is not the load request itself
- `HandleSelectSaveGame(N)` alone is not enough; `SelectTab(N)` is needed to update stored selection
- Direct writes to `+0x960` are not the preferred native path
- Manually recreating the payload is riskier than reusing the native pipeline

# Bridge implication

Implementation should target the native sequence:

```text
CreateLoadGamePanel()
→ CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
→ CPanelLoadGame::SendLoadGameRequest()
```

This document does not implement the bridge. It only records the native architecture that the bridge should reuse.

# Remaining implementation question

How to safely call these native functions in-process from the custom NUI bridge.

That is now the remaining implementation design problem, not a reverse-engineering problem.

# References

- [First-EndToEnd-HandleSelectSaveGame-Run.md](./First-EndToEnd-HandleSelectSaveGame-Run.md)
- [MultiProbe-LoadSelection-Timeline.md](./MultiProbe-LoadSelection-Timeline.md)
- [LoadRequest-Trace-20260702-220746.md](./LoadRequest-Trace-20260702-220746.md)
- [LoadRequest-Arguments.md](./LoadRequest-Arguments.md)
- [LoadRequest-Payload-Correlation.md](./LoadRequest-Payload-Correlation.md)
- [LoadRequest-Payload-Construction-Chain.md](./LoadRequest-Payload-Construction-Chain.md)
- [CPanelLoadGame-SendLoadGameRequest-State.md](./CPanelLoadGame-SendLoadGameRequest-State.md)
- [CPanelLoadGame-Lifecycle.md](./CPanelLoadGame-Lifecycle.md)
- [Native-State-Injection-Feasibility.md](./Native-State-Injection-Feasibility.md)
- [LoadPanel-Selection-Lifecycle.md](./LoadPanel-Selection-Lifecycle.md)
- [LoadPanel-Programmatic-Selection.md](./LoadPanel-Programmatic-Selection.md)
- [Final-Selection-Validation-Result.md](./Final-Selection-Validation-Result.md)
