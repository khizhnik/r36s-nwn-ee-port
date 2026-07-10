# Goal

Classify the native NWN:EE Load Game paths into:

1. usable / promising for the custom NUI Load screen
2. possible but risky
3. dead-end / unsupported

This is research-only. It does not implement save loading.

# Inputs

## Local evidence inspected

- `nwmain-linux` x86:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- `nwmain-linux` ARM64:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- NWScript header:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/ovr/nwscript.nss`
- Existing research notes:
  - `dev/research/nui/Native-Load-Game-Message-Flow.md`
  - `dev/research/nui/Native-Save-Loading-Pipeline.md`

## Commands used

- `nm -C`
- `readelf -Ws`
- `objdump -d -C`
- `strings`
- `rg`
- `file`
- `ldd`

# Summary classification table

| Path | Classification | Why | Evidence | Next step |
|---|---|---|---|---|
| NWScript API | Dead-end / unsupported | No exposed NWScript save-load API exists in the shipped header. | `rg` over `nwscript.nss` found only `DoSinglePlayerAutoSave()`, not `LoadGame`, `LoadSavedGame`, or `DeleteSave`. | Stop looking for a direct script API. |
| command-line argument | Dead-end / unsupported | I found startup switches like `+LoadNewModule` and `+TestNewModule`, but nothing that clearly loads a selected save. | `strings` in `nwmain-linux` and legacy docs. | Do not base save loading on CLI switches. |
| currentgame staging | Possible but risky | `CURRENTGAME` and `TEMPCLIENT` are real engine/userdir paths, and legacy docs mention `currentgame` in save/load troubleshooting, but I did not prove that staging alone loads a save. | `dev/pc/userdir/nwn.ini`, legacy docs, `strings` in `nwmain-linux`. | Watch real native load file changes before relying on it. |
| native UI automation | Possible but risky | The native Load UI already drives the correct engine path, but automation is timing/focus fragile and not a clean engine integration point. | Native UI symbols and current custom UI work. | Only consider if no direct or restart-based path proves viable. |
| `CPanelLoadGame::SendLoadGameRequest` | Possible but risky | This is the clearest native client-side handoff, but it requires a live `CPanelLoadGame*` and internal panel state. | x86/ARM64 symbols and disassembly. | Useful hook point, not a wrapper-facing API. |
| `CClientExoApp::SendLoadGameRequest` | Possible but risky | It is exported and very thin, but it tail-jumps into internal state and still needs a live app object. | x86/ARM64 symbols; x86 disassembly shows a direct jump to internal. | Good interception target, hard direct-call target. |
| `CNWCMessage::SendPlayerToServerModule_LoadGame` | Possible but risky | This is the actual message builder/transporter, but it still depends on client-side message context. | x86/ARM64 symbols; x86 disassembly shows `CClientExoAppInternal` tail-jumps here when transport exists. | Good to know, but not directly wrapper-friendly. |
| `CServerExoApp::LoadGame` | Possible but risky | This is the real server-side load entry, but it is not a wrapper-callable API and needs server context plus a `CNWSPlayer*`. | x86/ARM64 symbols; x86 disassembly shows it tail-jumps to `CServerExoAppInternal::LoadGame`. | Treat as internal engine endpoint only. |
| `CSaveGameList` reuse | Usable / promising | It already owns save enumeration, sorting, and metadata lookup; it is useful for matching our custom save list to engine behavior even though it does not itself perform the load transition. | `GetSaveGameList`, `GetSaveGameName`, `GetSaveGameFileInfo`, `SortSaveGameList`, `DeleteSaveGame`. | Keep using it as a reference model for list semantics and metadata. |
| LD_PRELOAD / native hook | Possible but risky | In principle a hook could intercept the native send-request path, but the object-context problem remains and the ABI is not a clean stable contract. | Exported global symbols exist on both x86 and ARM64. | Only if a process-internal hook becomes necessary. |
| gdb/manual call | Dead-end / unsupported | Useful for debugging, not a production integration path. | No evidence of a supported engine call entry from outside the process. | Do not plan around it. |
| restart-and-stage strategy | Usable / promising | This is the least invasive path that could plausibly work later if `currentgame` / `tempclient` staging behaves as legacy docs suggest. | `CURRENTGAME`, `TEMPCLIENT`, docs about `currentgame`, and the absence of a script API. | Highest-value path to validate next with a filesystem watch experiment. |

# Function evidence

All functions below were found as `FUNC GLOBAL DEFAULT` in `readelf -Ws` on both architectures, unless otherwise noted.

| Symbol | x86 address | ARM64 address | Exported/global/local | Signature | Notes |
|---|---:|---:|---|---|---|
| `CPanelLoadSave::HandleSelectSaveGame(int)` | `0x6fd500` | `0x6fbdc0` | Global / exported | `void (int)` | Selection is index-based. Disassembly shows it uses the selected index to build save-directory/resource-manager state, including `module_uuid.txt` and portrait handling. |
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6fa1d0` | `0x6f8e78` | Global / exported | `void ()` | Reads selected index from panel state and resolves it through `CSaveGameList` before calling `CClientExoApp::SendLoadGameRequest(...)`. |
| `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` | `0x637960` | `0x648580` | Global / exported | `void (unsigned int, CExoString&, CExoString&, int)` | Thin wrapper. x86 disassembly shows it immediately tail-jumps to `CClientExoAppInternal::SendLoadGameRequest(...)` after loading `this+0x8`. |
| `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` | `0x63c610` | `0x64cc10` | Global / exported | `void (unsigned int, CExoString&, CExoString&, int)` | Another thin wrapper. x86 disassembly shows a check of `this+0x208` and then a tail-jump to `CNWCMessage::SendPlayerToServerModule_LoadGame(...)`. |
| `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)` | `0x8027b0` | `0x7e4688` | Global / exported | `void (unsigned int, CExoString&, CExoString&, int)` | Actual message construction/send endpoint. Needs live client message context. |
| `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)` | `0x9fe780` | `0x9ad3a8` | Global / exported | `void (unsigned int, CExoString&, CExoString&, CNWSPlayer*)` | Server-side entry. x86 disassembly shows a tail-jump to `CServerExoAppInternal::LoadGame(...)`. |
| `CServerExoAppInternal::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)` | `0xa10290` | `0x9bd5e0` | Global / exported | `void (unsigned int, CExoString&, CExoString&, CNWSPlayer*)` | Internal implementation behind the public server wrapper. Not a practical wrapper target by itself. |
| `CSaveGameList::GetSaveGameList()` | `0x6fbe30` | `0x6fa888` | Global / exported | `void ()` | Enumerates save directories and augmented file info. This is the core native save list builder. |
| `CSaveGameList::GetSaveGameName(int)` | `0x6f7cc0` | `0x6f69f0` | Global / exported | `CExoString (int)` | Index-driven access to save names. |
| `CSaveGameList::GetSaveGameFileInfo(int)` | `0x6f7f10` | `0x6f6c38` | Global / exported | `CFileInfo-like (int)` | Returns metadata by index. This appears to be backed by the save list structures built earlier. |
| `CSaveGameList::SortSaveGameList()` | `0x6f8450` | `0x6f71c8` | Global / exported | `void ()` | Sorts save entries; the disassembly shows time comparisons and slot/index reordering. |
| `CSaveGameList::DeleteSaveGame(int)` | `0x6f8310` | `0x6f7028` | Global / exported | `void (int)` | Deletion is also index-based. x86 disassembly shows directory nuking via resource manager. |
| `CPanelLoadSave::PopulateListWithSaveDirContents()` | `0x6f91c0` | `0x6f7ee8` | Global / exported | `void ()` | Builds the GUI list from the save directory. x86 `strings` show it alongside `savenfo`, `module_uuid.txt`, and directory labels. |
| `CPanelLoadGame::GetSaveGameName()` | `0x6f9ef0` | `0x6f8b88` | Global / exported | `CExoString ()` | Panel-level getter, likely returning the currently selected save name. |
| `CPanelLoadGame::GetPlayerPassword()` | `0x6f9820` | `0x6f84c8` | Global / exported | `CExoString ()` | Present in the panel; likely used for password-protected or multiplayer-related load flow. |
| `CPanelLoadGame::HandleOkButton()` | `0x6f99a0` | `0x6f8690` | Global / exported | `void ()` | Button path into the load flow. |
| `CPanelLoadGame::HandleCancelButton()` | `0x6f6bf0` | `0x6f59a0` | Global / exported | `void ()` | Cancel path; not load-related. |
| `CPanelLoadGame::HandleDeleteButton()` | `0x6f9fc0` | `0x6f8c48` | Global / exported | `void ()` | UI deletion path. |
| `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)` | `0x6fa420` | `0x6f90c8` | Global / exported | `void (int)` | x86 disassembly shows `arg == 1` jumps directly to `SendLoadGameRequest()`. |
| `CPanelLoadGame::OnConnectServerStatusPanelExit(int)` | `0x6f7fa0` | `0x6f6cc8` | Global / exported | `void (int)` | Related panel state transition. |
| `CPanelLoadGame::BuildButtonList()` | `0x6f9810` | `0x6f84c0` | Global / exported | `void ()` | UI construction helper. |
| `CPanelLoadGame::Update(float)` | `0x6f6be0` | `0x6f5998` | Global / exported | `void (float)` | Present in symbol tables on both architectures. |

Notes on the table:

- All the named load/save functions above appear as `GLOBAL DEFAULT` in `readelf -Ws` on both x86 and ARM64 where re-queried.
- The exact ARM64 addresses for a few helper methods were not re-run individually in this pass, but the symbol names are present in `nm` output for ARM64.

## What the disassembly shows

### `CPanelLoadGame::SendLoadGameRequest()`

Confirmed from x86 disassembly:

- It reads the selected index from a panel field at `0x960`.
- It uses an internal mapping array at `0xd50` to convert the UI selection into another integer.
- It calls:
  - `CSaveGameList::GetSaveGameName(int)`
  - `CSaveGameList::GetSaveGameFileInfo(int)` twice
- It searches and slices strings, including the `module_uuid.txt` path fragment.
- It then calls `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`.

This is strong evidence that the native load flow is **index-driven** in the GUI layer.

### `CClientExoApp::SendLoadGameRequest(...)`

Confirmed from x86 disassembly:

- It immediately loads `this+0x8`.
- It tail-jumps directly to `CClientExoAppInternal::SendLoadGameRequest(...)`.

This means the exported client method is just a wrapper around internal state.

### `CClientExoAppInternal::SendLoadGameRequest(...)`

Confirmed from x86 disassembly:

- It checks a pointer at `this+0x208`.
- If the pointer is present, it tail-jumps to `CNWCMessage::SendPlayerToServerModule_LoadGame(...)`.
- If not, it returns `0`.

This means direct external calling would need the correct live client internal object and network context.

### `CServerExoApp::LoadGame(...)`

Confirmed from x86 disassembly:

- It loads `this+0x8`.
- It tail-jumps to `CServerExoAppInternal::LoadGame(...)`.

This is the real server endpoint, but not a wrapper-friendly entry point.

### `CPanelLoadSave::HandleSelectSaveGame(int)`

Confirmed from x86 disassembly:

- It is index-based, not folder-based.
- It can trigger resource-manager operations such as:
  - `CExoResMan::AddResourceDirectory(...)`
  - `CExoResMan::Exists(...)`
  - `CNWPortrait::ReplacePortraitTexture(...)`
- It references `module_uuid.txt` in its save-path building logic.

This strongly suggests the GUI selection path is already tied to save-directory resource lookup and portrait replacement.

### `CSaveGameList::GetSaveGameList()`

Confirmed from x86 disassembly:

- It calls `CExoBase::GetDirectoryList(...)`.
- It calls `CExoBase::GetAugmentedDirectoryList(...)`.
- It sorts / inserts slots by comparing file times.

This indicates `CSaveGameList` is the native save list constructor and sorter.

# What looks usable

- `CSaveGameList` for understanding native save ordering, metadata shape, and list semantics.
- `restart-and-stage strategy` as the least invasive candidate for actually loading a selected save later, because the shipped docs mention `currentgame` and `tempclient` and there is no NWScript load API.
- `CPanelLoadGame::SendLoadGameRequest()` as the best native client-side hook point if a process-internal bridge becomes necessary.

# What looks risky

- `currentgame` staging by itself.
- UI automation of the native Load dialog.
- Direct external calls into `CPanelLoadGame::SendLoadGameRequest()`.
- Direct external calls into `CClientExoApp::SendLoadGameRequest()`.
- Direct external calls into `CNWCMessage::SendPlayerToServerModule_LoadGame()`.
- Direct external calls into `CServerExoApp::LoadGame()`.
- LD_PRELOAD / native hook approaches.

The common risk is the same: these routines are exported, but they still require a live object graph and internal client/server state.

# What looks like a dead end

- NWScript API for save loading.
- Command-line save-load arguments.
- `gdb` / manual function calls as a production path.

These are either unsupported or not stable integration mechanisms.

# Recommended next minimal experiments

Exactly one minimal experiment gives the best return:

1. Perform a real native save load once and watch `CURRENTGAME` / `TEMPCLIENT` / `modules` before and after.

Why this is the best next experiment:

- It is non-invasive.
- It can confirm whether the engine stages files on disk as part of load.
- It decides whether the wrapper should pursue:
  - filesystem staging / restart, or
  - a process-internal hook / UI automation path.

# Final recommendation

Investigate **A. filesystem/currentgame behavior** next.

Reason:

- It is the smallest experiment that can tell us whether the most promising path is actually viable.
- If `currentgame`/`tempclient` behavior matches the legacy docs, then a restart-and-stage load path becomes the cleanest implementation candidate.
- If it does not, the next fallback would be a native UI automation or hook-based path, but those should stay secondary until the filesystem behavior is understood.
