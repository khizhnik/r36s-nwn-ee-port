# Goal

Reconstruct the native save-selection lifecycle from `CPanelLoadSave::HandleSelectSaveGame(int)` up to the point where `CPanelLoadGame::SendLoadGameRequest()` can be issued.

This note is research-only. It does not implement save loading.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Native binary inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- NWScript header inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/ovr/nwscript.nss`
- Prior notes referenced:
  - `dev/research/nui/Native-Load-Game-Message-Flow.md`
  - `dev/research/nui/Native-CSaveGameList-Data-Model.md`
  - `dev/research/nui/GetAugmentedDirectoryList-Analysis.md`

## Commands used

- `nm -C`
- `readelf -Ws`
- `objdump -d -C`
- `strings`
- `rg`
- `file`
- `ldd`

## Confirmed selection-path evidence

Disassembly of `CPanelLoadSave::HandleSelectSaveGame(int)` shows that the selection path is index-based and performs native save setup work before any load request is sent.

The observed flow includes:

- checking the selected index
- querying `CSaveGameList`
- building a save-folder path
- registering that path with the resource manager
- replacing portrait texture data
- opening and parsing save-related data
- extracting character metadata
- updating GUI subobjects through virtual calls

This is the native lifecycle boundary between save-slot selection and later load request dispatch.

# HandleSelectSaveGame algorithm

The best evidence-based reconstruction of `CPanelLoadSave::HandleSelectSaveGame(int)` is:

1. Receive the selected save index.
2. Reject invalid or busy UI states early.
3. Check whether the clicked slot is an empty-slot placeholder.
4. If the slot is a real save:
   1. Query the save name from `CSaveGameList::GetSaveGameName(int)`.
   2. Build the save-folder path string.
   3. Register that folder with the resource manager using `CExoResMan::AddResourceDirectory(...)`.
   4. Build a portrait resource reference and call `CNWPortrait::ReplacePortraitTexture(...)`.
   5. Check whether the resource is now visible with `CExoResMan::Exists(...)`.
   6. Open and parse save-related data with `CExoFile` and `CResGFF`.
   7. Query `CSaveGameList::GetSaveGameFileInfo(int)` for indexed file-info data.
   8. Extract character full name, class name, and class level from `CNWCCreatureStats`.
   9. Format the derived strings for GUI display.
   10. Update GUI subobjects and labels.
5. If the slot is an empty placeholder:
   1. Follow a distinct resource-registration path.
   2. Update the UI accordingly.
6. Leave the panel in a state where the later load button can use the selected slot.

## What is confirmed

- The lifecycle is index-based.
- The selection path stores or reuses a selected slot index.
- `CSaveGameList` is queried from the selection path.
- Resource manager state is updated during selection.
- Portrait replacement is triggered during selection.
- Character metadata is parsed during selection.
- GUI subobjects are updated during selection.

## What is likely

- The panel stores selected-save state for later `SendLoadGameRequest()`.
- The selection path prepares the resource manager so save-specific assets resolve correctly.
- Preview and portrait state are refreshed as part of selection handling.

## What is unknown

- The exact internal fields used to store selected state.
- Whether `screen.tga` is directly handled in this function or by a helper called from it.
- Whether `savenfo.txt` is explicitly read here or only indirectly reflected in later GUI state.
- The exact meaning of every temporary string built inside the function.

# Direct callees

| Callee | Purpose | Evidence |
|---|---|---|
| `CPanelLoadSave::GetIsEmptySlotButton(int)` | Detects placeholder slots | Direct call in selection flow. |
| `CSaveGameList::GetSaveGameName(int)` | Resolves the save name for the selected slot | Direct call before resource/path setup. |
| `CSaveGameList::GetSaveGameFileInfo(int)` | Fetches indexed file-info metadata | Direct call during save-data parsing. |
| `CExoResMan::AddResourceDirectory(...)` | Registers the selected save directory with the resource manager | Direct call in selection flow. |
| `CExoResMan::Exists(CResRef const&, unsigned short, unsigned int*)` | Checks whether the selected resource is visible after registration | Direct call after portrait/resource setup. |
| `CExoResMan::RemoveResourceDirectory(CExoString const&)` | Removes a save directory from the resource manager in the empty-slot path | Direct call in the alternate branch. |
| `CNWPortrait::ReplacePortraitTexture(CAurObject*, CResRef const&)` | Swaps the preview portrait texture | Direct call in selection flow. |
| `CExoFile::CExoFile(...)` | Opens a save-related file | Direct call in the metadata parsing branch. |
| `CExoFile::GetSize()` | Reads file size before parsing | Direct call in the metadata parsing branch. |
| `CExoFile::Read(CExoString&, unsigned int)` | Reads save-related text/data | Direct call in the metadata parsing branch. |
| `CResGFF::CResGFF(...)` | Builds a GFF reader for save data | Direct call in the metadata parsing branch. |
| `CResGFF::GetTopLevelStruct(CResStruct*)` | Reads the save-data top-level struct | Direct call in the metadata parsing branch. |
| `CNWCLevelUpStats::CNWCLevelUpStats()` | Temporary stats object used while parsing creature data | Direct call in the metadata parsing branch. |
| `CNWCCreatureStats::ReadStatsFromGff(CResGFF*, CResStruct*)` | Parses creature metadata from save data | Direct call in the metadata parsing branch. |
| `CNWCCreatureStats::GetFullName()` | Extracts character full name | Direct call in the metadata parsing branch. |
| `CNWCCreatureStats::GetClass(unsigned char)` | Resolves class data | Direct call in the metadata parsing branch. |
| `CNWCCreatureStats::GetClassLevel(unsigned char)` | Resolves class level | Direct call in the metadata parsing branch. |
| `CNWClass::GetShortNameText()` / `CNWClass::GetNameText()` | Produces localized class text | Direct call in the metadata parsing branch. |
| `CPanelLoadSave::ConvertFilenameToStrRef(CExoString const&)` | Converts filename-derived text into a string reference | Direct call in the metadata parsing branch. |

# Save semantics boundary

The current evidence suggests that save semantics begin in the selection path, not in raw directory enumeration.

| Semantic item | Where handled | Status | Evidence |
|---|---|---|---|
| selected index | `CPanelLoadSave::HandleSelectSaveGame(int)` | Confirmed | The callback is explicitly index-based. |
| save folder path | `HandleSelectSaveGame(int)` | Confirmed | The path is built before resource registration. |
| save name | `HandleSelectSaveGame(int)` and `CSaveGameList::GetSaveGameName(int)` | Confirmed | The selection path queries indexed save names. |
| resource-manager registration | `HandleSelectSaveGame(int)` | Confirmed | `AddResourceDirectory(...)` is called. |
| portrait replacement | `HandleSelectSaveGame(int)` | Confirmed | `CNWPortrait::ReplacePortraitTexture(...)` is called. |
| character name | `HandleSelectSaveGame(int)` | Confirmed | `CNWCCreatureStats::GetFullName()` is called. |
| class / class level | `HandleSelectSaveGame(int)` | Confirmed | `GetClass(...)` and `GetClassLevel(...)` are called. |
| save file-info record | `CSaveGameList::GetSaveGameFileInfo(int)` | Confirmed | The selection path queries indexed file info. |
| preview screenshot | `HandleSelectSaveGame(int)` or a helper it calls | Likely | The path touches save resources and portrait setup, but the exact screenshot handling branch is not fully isolated. |
| `savenfo.txt` | selection path or a helper it calls | Unknown | No direct, isolated proof yet. |
| `module_uuid.txt` | selection path or a helper it calls | Unknown | Prior notes suggest it is touched in the selection/load flow, but this function-level boundary is not fully isolated. |

# Resource manager behavior

The selection path does more than read a raw index.

Evidence strongly suggests that `HandleSelectSaveGame(int)` registers the chosen save directory with the resource manager so save-specific assets become visible to later lookups.

This is shown by:

- `CExoResMan::AddResourceDirectory(...)`
- `CExoResMan::Exists(...)`
- `CNWPortrait::ReplacePortraitTexture(...)`

## What is confirmed

- Selection changes resource-manager state.
- Resource visibility is tested immediately after registration.
- Portrait replacement is part of that resource setup.

## What is not confirmed

- Whether the selected save directory is cached permanently or only temporarily.
- Whether `module_uuid.txt`, `screen.tga`, or `savenfo.txt` are individually read in this specific function.

# Portrait and preview behavior

## Portrait

Confirmed:

- The selection path calls `CNWPortrait::ReplacePortraitTexture(...)`.
- Character metadata is parsed during selection.

Likely:

- The portrait shown in the native Load Game UI is refreshed during selection.

Unknown:

- Exact source of the portrait reference in this function-level boundary.
- Whether portrait resolution comes from `player.bic`, `portrait.tga`, or both.

## Preview

Likely:

- The preview area is refreshed during selection.

Unknown:

- The exact function that binds `screen.tga` to the GUI preview.
- Whether the preview is loaded by the selection callback itself or a helper it calls.

# Contract before SendLoadGameRequest

Before the native load request can work correctly, the selection path appears to prepare at least the following state:

- selected save index
- save name / slot identity
- save directory registered with the resource manager
- derived portrait texture state
- character metadata
- GUI-visible labels / subwindow state

## Confirmed

- indexed selection exists
- save name lookup exists
- file-info lookup exists
- resource-manager state is prepared
- portrait replacement occurs

## Likely

- selected-save state is stored for later load-button use
- the load button uses the selection already prepared by `HandleSelectSaveGame(int)`

## Unknown

- exact internal field names
- exact selection contract consumed by `CPanelLoadGame::SendLoadGameRequest()`
- whether any password or client/session state is also required

# Comparison with custom NUI flow

| Native step | Custom step | Equivalent? | Comments |
|---|---|---|---|
| Select save by index | Click save entry, store `R36S_SELECTED_SAVE_INDEX` | Equivalent | Both are index-based. |
| Derive selected folder | Wrapper stores `R36S_SELECTED_SAVE_FOLDER` | Equivalent | The wrapper makes the folder explicit. |
| Register save resources | Wrapper stages `r36s_preview.tga` and metadata files in `development/` | Different | The wrapper approximates the effect outside the engine rather than using native resource registration. |
| Refresh portrait | NUI renders `portrait_resref + "l"` | Equivalent in effect | The wrapper already exposes the portrait data directly. |
| Refresh preview | NUI renders `r36s_preview` | Equivalent in effect | The wrapper already supplies the preview asset. |
| Update GUI metadata | NUI shows save name, area, time, character, class, level | Better custom | The wrapper exposes richer metadata explicitly. |
| Prepare for load request | Wrapper emits `R36S_BOOTSTRAP_LOAD_SAVE_REQUESTED|<index>|<folder>` | Equivalent in bridge form | The native path is still not implemented. |

# Remaining unknowns

The biggest unresolved items are:

1. The exact internal state stored by `HandleSelectSaveGame(int)`.
2. The exact save-resource branch that prepares preview screenshot handling.
3. Whether `savenfo.txt` is read directly in this function or through a helper.
4. The exact parameter contract of `CPanelLoadGame::SendLoadGameRequest()`.
5. Whether the wrapper can map its selected-save state directly onto the native load request without patching the engine.

# Final conclusion

Do we now understand enough of the native save-selection lifecycle to design the next integration experiment?

**Yes.**

We do not know every internal field, but we now understand the lifecycle boundary well enough to design the next experiment:

- selection is index-based
- the selection callback prepares resource-manager state
- portrait refresh happens in the selection path
- save metadata is queried from `CSaveGameList`
- the GUI is updated before `SendLoadGameRequest()`

That is enough to design the next integration experiment without yet implementing native loading.

# Recommended next experiment

Trace the exact data consumed by `CPanelLoadGame::SendLoadGameRequest()` after a selection has been made, and compare it against the wrapper’s current selected-index / selected-folder bridge.

Why this is the best next step:

- the selection lifecycle is now sufficiently clear
- the remaining uncertainty is the handoff contract into the load request
- that contract is the last major obstacle before deciding how the wrapper should trigger native loading
