# Goal

Determine the minimum native engine state that exists after `HandleSelectSaveGame(int)` completes and before `SendLoadGameRequest()` is issued.

This note is research-only. It does not implement anything.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Native binary inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- Relevant prior notes:
  - `dev/research/nui/Native-Save-Selection-Lifecycle.md`
  - `dev/research/nui/Native-Save-Loading-Pipeline.md`
  - `dev/research/nui/Native-Load-Game-Message-Flow.md`
  - `dev/research/nui/Native-CSaveGameList-Data-Model.md`

## Evidence basis

The native selection path is known to:

- take an index as input
- query `CSaveGameList`
- register a save directory with the resource manager
- refresh portrait state
- parse save-related character metadata
- update GUI subobjects

The remaining question is not how the code works instruction by instruction, but what state must exist once the selection callback has finished.

# Native state inventory

| State | Owner | Lifetime | Status | Evidence |
|---|---|---|---|---|
| selected index | `CPanelLoadSave` / GUI state | persists until another slot is selected | Confirmed | `HandleSelectSaveGame(int)` is index-based and drives later load behavior. |
| selected save name | `CSaveGameList` / panel cache | persists until another slot is selected | Confirmed | The selection path queries `GetSaveGameName(int)`. |
| selected save folder/path | `CPanelLoadSave` and/or resource-manager registration state | persists at least until the next selection | Likely | The selection path builds a save-folder path and registers it with `AddResourceDirectory(...)`. |
| registered resource directory | `CExoResMan` singleton | persists until removed or replaced | Confirmed | `AddResourceDirectory(...)` is called during selection and `RemoveResourceDirectory(...)` exists for the alternate branch. |
| portrait resource state | portrait subsystem / GUI preview object | persists until another slot is selected | Confirmed | `CNWPortrait::ReplacePortraitTexture(...)` is called. |
| file-info record | `CSaveGameList` | persists inside indexed save-list storage | Confirmed | `GetSaveGameFileInfo(int)` is called from the selection path and from the later request path. |
| parsed character full name | temporary parsing object and GUI labels | transient during parsing, then copied into GUI state | Confirmed | `CNWCCreatureStats::GetFullName()` is called and formatted text is emitted. |
| parsed class / level | temporary parsing object and GUI labels | transient during parsing, then copied into GUI state | Confirmed | `GetClass(...)` and `GetClassLevel(...)` are called. |
| preview resource binding | GUI / resource manager | likely persists until another selection | Likely | Save-resource registration and preview/portrait refresh happen in the selection callback, but the exact binding object is not isolated. |
| button enabled state | GUI control state | persists until next UI mutation | Likely | Selection path updates subwindows and likely enables load-related controls, but the exact enable call was not isolated. |
| pending load target | `CPanelLoadGame` / panel state | persists until `SendLoadGameRequest()` | Likely | The later load-request path reads the selected index and save metadata. |
| password string | `CPanelLoadGame` / GUI state | persists until request time | Unknown | `GetPlayerPassword()` exists, but selection-state evidence does not prove when or how it is populated. |
| module UUID | selection-path helper / save-resource state | likely persists until request time | Unknown | `module_uuid.txt` is implicated by selection/load research, but the exact state boundary is not fully isolated. |
| temporary GFF parse objects | stack / temporaries | transient only | Confirmed | `CResGFF`, `CNWCCreatureStats`, and `CNWCLevelUpStats` are constructed during selection parsing. |

# Timeline

The post-selection lifecycle likely looks like this:

1. The user selects a save slot by index.
2. `CPanelLoadSave::HandleSelectSaveGame(int)` validates the selection.
3. The panel queries `CSaveGameList` for indexed save data.
4. The save folder is built and registered with the resource manager.
5. Portrait state is refreshed.
6. Save-related data is parsed.
7. Character metadata is extracted and formatted.
8. GUI labels and subwindows are updated.
9. The selected-save state remains resident in panel / list / resource-manager state.
10. The load button later uses that existing state when `SendLoadGameRequest()` is invoked.

## Confirmed

- Selection is index-driven.
- Resource manager registration occurs during selection.
- Portrait replacement occurs during selection.
- Character metadata parsing occurs during selection.
- GUI refresh occurs during selection.

## Likely

- The panel stores a pending load target.
- The selected folder/path is retained long enough for the later load request.
- The GUI load button is enabled or updated after valid selection.

## Unknown

- Exact ownership of the pending load target.
- Whether the preview binding is a direct GUI field, a resource-manager alias, or both.

# State mutation

When another save is selected, the engine likely mutates the following:

- selected index changes
- selected save name changes
- selected folder/path changes
- resource-manager registration changes
- portrait texture changes
- parsed metadata changes
- GUI labels change
- any prior pending load target is overwritten

## Persisting objects

Likely persistent across selections:

- `CSaveGameList` indexed arrays
- `CExoResMan` singleton
- GUI panel object

Likely rebuilt or refreshed on selection:

- temporary parsing objects
- preview/portrait bindings
- formatted label strings

# Comparison with wrapper

| Native | Wrapper | Equivalent? | Comments |
|---|---|---|---|
| selected index | `R36S_SELECTED_SAVE_INDEX` | Yes | The wrapper makes the selected index explicit. |
| selected folder/path | `R36S_SELECTED_SAVE_FOLDER` | Yes | The wrapper exposes the save folder directly. |
| save name | `save_name` in `r36s_saveindex.txt` | Yes | Same user-facing concept. |
| file-info record | `mtime`, `module_name` and indexed save fields | Partial | Wrapper stores richer text metadata than native `CFileInfo` exposes to the GUI. |
| registered resource directory | staged `development/r36s_preview.tga` and metadata files | Different | Wrapper simulates resource visibility by file staging rather than engine registration. |
| portrait replacement | NUI `NuiImage` of `portrait_resref + "l"` | Different in mechanism, same in effect | The wrapper supplies the portrait directly to the UI. |
| preview refresh | NUI `NuiImage("r36s_preview")` | Different in mechanism, same in effect | The wrapper supplies the preview directly to the UI. |
| label refresh | NUI text fields | Yes | The wrapper already recreates the visible label state. |
| pending load target | `R36S_BOOTSTRAP_LOAD_SAVE_REQUESTED|<index>|<folder>` | Partially | The wrapper captures the selection, but native request state is still not reproduced. |

# Minimum contract before SendLoadGameRequest

## Confirmed

The following state is definitely required:

- a selected save index exists
- the save name and file-info record for that index are available
- the panel has already accepted the save as a valid selection
- the resource manager has been primed for the selected save
- the GUI has been updated to reflect that selection

## Likely

The following state is probably required:

- selected folder/path or equivalent save identity
- pending load target stored on the panel
- portrait/preview state corresponding to the current selection

## Unknown

The following is still not proven:

- exact password/session state requirements
- exact module UUID representation passed into the load request
- whether `SendLoadGameRequest()` relies on any other cached GUI state beyond the selected index and save-name/file-info data

# Final assessment

If we could reproduce this state ourselves, would `SendLoadGameRequest()` become the only remaining unknown?

**No.**

Reproducing the state would remove a major obstacle, but not all uncertainty.

Why:

- we still do not know the exact request payload semantics of `SendLoadGameRequest(...)`
- we still do not know whether password/session/module-UUID state must be synthesized exactly
- we still do not know whether the engine expects a specific internal panel object graph rather than just equivalent data values

So the state model is now clear enough to guide the next experiment, but not yet sufficient to claim the request path is fully solved.

# Recommended next experiment

Trace the exact panel fields or helper calls that `CPanelLoadGame::SendLoadGameRequest()` reads after a selection has been made, and compare them against the wrapper’s current selected-index / selected-folder bridge.

Why this is the best next step:

- it validates which pieces of state are truly required
- it separates “panel-held state” from “list-held state”
- it is the smallest remaining experiment that can tell us whether the wrapper is already synthesizing enough of the native contract
