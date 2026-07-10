# Goal

Understand the native NWN:EE Load Game pipeline well enough to later connect the custom save-selection bridge to the engine's real load path.

This note is research-only. It does not implement save loading.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Steam install: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights`
- Native binary inspected: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- NWScript header inspected: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/ovr/nwscript.nss`
- Userdir config inspected: `~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir/nwn.ini`
- Local docs inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/Neverwinter Nights Enhanced Edition (v79).txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/Neverwinter Nights Enhanced Edition (v76).txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/NWNv169.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/NWN_readme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/HotUreadme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/SoUreadme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/SQLite_README.txt`

## Search terms used

- `LoadGame`
- `LoadSavedGame`
- `DeleteSave`
- `SaveGame`
- `currentgame`
- `tempclient`
- `savenfo`
- `module_uuid`
- `quicksave`
- `autosave`
- `CPanelLoadGame`
- `CPanelLoadSave`
- `CSaveGameList`
- `SendLoadGameRequest`
- `SendPlayerToServerModule_LoadGame`
- `CServerExoApp::LoadGame`

# Native load pipeline

## Confirmed

The native client contains an internal load-save flow, visible in the stripped symbol table and disassembly:

- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadGame::SendLoadGameRequest()`
- `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
- `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
- `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
- `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`
- `CServerExoAppInternal::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`
- `CServerExoAppInternal::DealWithLoadGameError(unsigned int)`

This confirms that the built-in Load Game screen does not call a NWScript function. It hands off to a native client/server request path.

## Likely

The GUI layer appears to be index-driven:

- `CPanelLoadSave::HandleSelectSaveGame(int)` takes an integer.
- `CPanelLoadGame::SendLoadGameRequest()` reads a selected integer from panel state and resolves save data through `CSaveGameList`.

The selected save is therefore likely represented by a GUI slot/index plus derived save-name metadata, not by a raw folder string alone.

## Unknown

- The exact contents of the request payload passed through `SendLoadGameRequest(...)`.
- Whether the payload strings are folder names, save names, module names, passwords, or some combination.
- Whether the wrapper can trigger this path directly without UI automation or client-side patching.

# Binary symbols

## `CPanelLoadSave`

Relevant symbols discovered in `nwmain-linux`:

- `CPanelLoadSave::PopulateListWithSaveDirContents()`
- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadSave::DeleteSelectedSaveGame()`
- `CPanelLoadSave::HandleDeleteClick(int)`
- `CPanelLoadSave::InsertButton(int, int, CExoString, CExoString, CExoString)`
- `CPanelLoadSave::AddButton(int, CExoString, CExoString, CExoString)`
- `CPanelLoadSave::GetIsEmptySlotButton(int)`
- `CPanelLoadSave::PostAttachmentInitialize(int)`
- `CPanelLoadSave::ConvertFilenameToStrRef(CExoString const&)`

## `CPanelLoadGame`

Relevant symbols discovered in `nwmain-linux`:

- `CPanelLoadGame::HandleOkButton()`
- `CPanelLoadGame::HandleCancelButton()`
- `CPanelLoadGame::HandleDeleteButton()`
- `CPanelLoadGame::SendLoadGameRequest()`
- `CPanelLoadGame::GetSaveGameName()`
- `CPanelLoadGame::GetPlayerPassword()`
- `CPanelLoadGame::HandleOkPanelExit(int)`
- `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)`
- `CPanelLoadGame::OnConnectServerStatusPanelExit(int)`
- `CPanelLoadGame::BuildButtonList()`
- `CPanelLoadGame::Update(float)`

## `CSaveGameList`

Relevant symbols discovered in `nwmain-linux`:

- `CSaveGameList::GetSaveGameList()`
- `CSaveGameList::GetSaveGameName(int)`
- `CSaveGameList::GetSaveGameFileInfo(int)`
- `CSaveGameList::SortSaveGameList()`
- `CSaveGameList::DeleteSaveGame(int)`
- `CSaveGameList::InsertEmptySlot(int)`
- `CSaveGameList::CompareTwoTimes(CFileInfo*, CFileInfo*)`

## Client/server request path

Relevant symbols discovered in `nwmain-linux`:

- `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
- `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
- `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
- `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`
- `CServerExoAppInternal::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`
- `CServerExoAppInternal::DealWithLoadGameError(unsigned int)`

# Message flow

## Confirmed call chain

The most defensible native chain is:

1. `CPanelLoadSave::HandleSelectSaveGame(int)`
2. `CPanelLoadGame::SendLoadGameRequest()`
3. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
4. `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
5. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
6. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

## Likely message contents

Evidence from disassembly shows:

- The client-side panel holds a selected integer slot/index.
- That index is used to query `CSaveGameList::GetSaveGameName(int)` and `CSaveGameList::GetSaveGameFileInfo(int)`.
- The outgoing request is assembled from:
  - an `unsigned int`
  - two `CExoString` values
  - an `int`

What those fields mean exactly is not fully proven from the binary alone.

Most likely candidates:

- save slot/index
- save name / folder-derived string
- module or password-related string
- another integer flag or slot discriminator

## Unsupported by current evidence

There is no evidence that the request is sent directly from NWScript.

There is no evidence that a raw save folder string alone is the native load API surface.

# Save metadata ownership

## Save list

**Most likely owner:** `CSaveGameList`

Evidence:

- `CSaveGameList::GetSaveGameList()` enumerates save directory contents.
- `CSaveGameList::GetSaveGameName(int)` returns save names by index.
- `CSaveGameList::GetSaveGameFileInfo(int)` returns metadata by index.
- `CSaveGameList::SortSaveGameList()` sorts the list.

## Selection

**Most likely owner:** `CPanelLoadSave`

Evidence:

- `CPanelLoadSave::HandleSelectSaveGame(int)` is the selection callback.
- The GUI selection is index-based.

## Preview

**Likely owner:** `CSaveGameList` plus GUI panel consumers

Evidence:

- The save list machinery enumerates save directories and file info.
- `HandleSelectSaveGame(int)` references resource manager operations and `module_uuid.txt`.
- The docs and strings indicate the save pipeline is aware of save-folder resources.

What is still unknown:

- whether `screen.tga` is parsed by `CSaveGameList` itself or by a helper deeper in the engine
- whether preview/portrait metadata is stored in the same structure returned by `GetSaveGameFileInfo(int)` or constructed on demand

## Portrait

**Likely owner:** save-list / metadata parsing path, consumed by GUI or portrait helper code

Evidence:

- `HandleSelectSaveGame(int)` contains calls related to portrait texture replacement.
- The binary contains `CNWPortrait::ReplacePortraitTexture(...)`.

What is still unknown:

- whether the portrait is resolved from `player.bic`, `portrait.tga`, or both in different phases
- which class populates the portrait reference for the preview UI

## Loading

**Most likely owner:** `CPanelLoadGame` on the client side, then `CClientExoAppInternal` / `CNWCMessage` / `CServerExoApp`

Evidence:

- the client panel has `SendLoadGameRequest()`
- the engine has a dedicated client-to-server load message

## Deletion

**Most likely owner:** `CSaveGameList`

Evidence:

- `CSaveGameList::DeleteSaveGame(int)` exists
- `CPanelLoadSave::DeleteSelectedSaveGame()` delegates into list deletion
- the binary uses `CExoResMan::NukeDirectory(...)` on the selected save path

# Possible integration points

## Most promising

### 1. Wrapper reacts to `R36S_BOOTSTRAP_LOAD_SAVE_REQUESTED|<index>|<folder>` and then drives the native client path indirectly

Why it is promising:

- The native engine already has a load-save request pipeline.
- The current custom UI already gives us the save selection index and folder.

What remains unknown:

- how to inject the native request cleanly from the wrapper side
- whether UI automation, file staging, or process restart is required

## Possible

### 2. Restart-based strategy

Why it is possible:

- The engine exposes `CURRENTGAME` and `TEMPCLIENT` paths in config.
- Legacy docs repeatedly mention `currentgame` as part of the save-load ecosystem.

Why it is still uncertain:

- No evidence yet that staging `currentgame` alone is enough to resume a save.

### 3. UI automation of the native Load dialog

Why it is possible:

- The native load flow is fully implemented in the client UI.
- A wrapper can, in principle, automate GUI interaction.

Why it is less ideal:

- It is fragile and depends on UI timing and focus.

## Unlikely

### 4. Direct NWScript save-load API

Why unlikely:

- No `LoadGame`, `LoadSavedGame`, or `DeleteSave` NWScript function was found in `nwscript.nss`.

### 5. Direct command-line save-load switch

Why unlikely:

- Searches of shipped docs and binary strings did not reveal a save-specific startup switch.

## Unsupported

### 6. Treating the selected folder string as a complete native load request

Why unsupported:

- The native GUI code is index-driven.
- The request builder resolves save metadata through `CSaveGameList`, so a folder string alone is not proven sufficient.

# Recommended next experiment

Capture a real native save load and watch the filesystem behavior around `currentgame` and `tempclient`.

Smallest useful experiment:

1. Start NWN normally.
2. Load one save through the native Load UI.
3. Record which files and directories change under:
   - `CURRENTGAME`
   - `TEMPCLIENT`
   - the save directory itself
4. Compare the before/after state.

Why this is the best next step:

- It requires no code changes.
- It can prove whether the engine stages load state through filesystem copies.
- It will tell us whether the wrapper should eventually emulate native load by staging files, by UI automation, or by a process restart path.