# Goal

Reverse engineer the native `CSaveGameList` data model well enough to understand the object that sits between the GUI and `SendLoadGameRequest()`.

This note is research-only. It does not implement save loading.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Native binary inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- NWScript header inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/ovr/nwscript.nss`

## Commands used

- `nm -C`
- `readelf -Ws`
- `objdump -d -C`
- `strings`
- `rg`
- `file`
- `ldd`

## Previously established load chain

The GUI and native load path were already identified in prior research as:

`CPanelLoadSave::HandleSelectSaveGame(int)`
-> `CPanelLoadGame::SendLoadGameRequest()`
-> `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
-> `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
-> `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
-> `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

The remaining question is the save-slot data model behind `CSaveGameList`.

# Complete CSaveGameList API

The exported `CSaveGameList` methods found in `nwmain-linux` are:

| Method | Purpose | Evidence |
|---|---|---|
| `CSaveGameList::CSaveGameList()` | Constructor. Initializes internal arrays, populates the list, then sorts it. | x86/ARM64 symbol lookup plus x86 disassembly of the constructor. |
| `CSaveGameList::GetSaveGameList()` | Builds the native save list from the save directory. | x86/ARM64 symbol lookup plus x86 disassembly showing directory enumeration and augmented file-info collection. |
| `CSaveGameList::GetSaveGameName(int)` | Returns the display/save name for a slot index. | x86/ARM64 symbols plus call sites in `CPanelLoadSave` and `CPanelLoadGame`. |
| `CSaveGameList::GetSaveGameFileInfo(int)` | Fills a caller-provided file-info object for a slot index. | x86/ARM64 symbols plus disassembly showing indexed out-parameter copying. |
| `CSaveGameList::SortSaveGameList()` | Sorts the save list. | x86/ARM64 symbols plus disassembly showing time comparisons and index reordering. |
| `CSaveGameList::CompareTwoTimes(CFileInfo*, CFileInfo*)` | Compares two file-info timestamps. | x86/ARM64 symbols plus disassembly of time-field comparisons. |
| `CSaveGameList::InsertEmptySlot(int)` | Inserts an empty-slot placeholder entry. | x86/ARM64 symbols plus disassembly creating an `EmptySlot` entry. |
| `CSaveGameList::DeleteSaveGame(int)` | Deletes a save by index. | x86/ARM64 symbols plus disassembly showing directory removal via resource manager. |

No destructor symbol or additional exported `CSaveGameList` methods were found in the symbol scan.

# How GetSaveGameList() works

## Step-by-step algorithm

The x86 disassembly supports the following algorithm:

1. Construct a save-root `CExoString` path.
2. Call `CExoBase::GetDirectoryList(CExoArrayList<CExoString>*, CExoString, unsigned short, int, int, int)` to enumerate save directories.
3. Iterate over the returned directories.
4. For each directory, build a per-save path string.
5. Call `CExoBase::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)` to gather file-info records for the save folder.
6. Store the returned save name and file-info data into internal arrays.
7. Store or update the slot index mapping array.
8. Sort the result with `SortSaveGameList()`.

## What this does not prove

The disassembly does **not** show `GetSaveGameList()` directly parsing:

- `savenfo.txt`
- `player.bic`
- `screen.tga`

Those assets may be processed by the augmented directory helper or by higher-level panel code, but that is not proven here.

## Likely data structure behind the list

The constructor zeroes three 16-byte regions inside `CSaveGameList`, which strongly suggests three internal dynamic-array-like members:

- a save-name array
- a file-info array
- an index/order mapping array

That layout is **likely**, based on constructor initialization and accessor behavior, but it is not fully type-annotated from the binary.

# SaveSlot model

This is the best reconstruction from the evidence.

## Reconstructed structure

```text
CSaveGameList
  - save-name storage
  - file-info storage
  - index/order mapping storage
```

## Logical save slot

```text
SaveSlot
  index
  displayName
  fileInfo
  orderIndex
  emptySlotMarker
  derived metadata (likely, not confirmed to live in CSaveGameList)
```

## Field classification

| Field | Status | Evidence |
|---|---|---|
| `index` | Confirmed | GUI and `CSaveGameList` access are index-based. |
| `displayName` / save name | Confirmed | `GetSaveGameName(int)` exists and is used by panel code. |
| `fileInfo` | Confirmed | `GetSaveGameFileInfo(int)` fills a `CFileInfo`-like object. |
| `orderIndex` / slot mapping | Likely | Constructor, `GetSaveGameFileInfo`, and `SortSaveGameList` show a separate index mapping array. |
| `emptySlotMarker` | Confirmed | `InsertEmptySlot(int)` exists and emits `EmptySlot`. |
| `folder name` | Likely | Panel code and delete/load logic operate on save-directory names, but `CSaveGameList` itself is not proven to store the raw folder as a distinct field. |
| `module name` | Likely | The native load path uses module-related strings and `module_uuid.txt`, but the exact storage location is not proven. |
| `module UUID` | Likely | `module_uuid.txt` appears in the selection/load path, but the exact field ownership is not fully proven. |
| `character name` | Likely | Selection code reads `player.bic`-related data, but the exact storage boundary is not proven. |
| `portrait resref` | Likely | Selection code touches portrait replacement; exact storage boundary is not proven. |
| `preview screenshot` | Likely | Save preview resources are visible in the save pipeline, but the exact storage boundary is not proven. |
| `timestamp` | Confirmed | `CFileInfo` holds a time-like record and `CompareTwoTimes()` sorts on it. |

## `CFileInfo` reconstruction

`GetSaveGameFileInfo(int)` behaves like an out-parameter fill for a `CFileInfo`-like object.

Confirmed by disassembly:

- a string-like field at offset `0x0`
- a length/auxiliary field at offset `0x8`
- six 16-bit fields at offsets `0x10`, `0x12`, `0x14`, `0x16`, `0x18`, `0x1a`

`CompareTwoTimes(CFileInfo*, CFileInfo*)` compares those six 16-bit fields in order, which makes them time-like components.

## Confirmed / likely / unknown split

### Confirmed

- Save slots are index-driven.
- `CFileInfo` is part of the model.
- Time-like components exist in `CFileInfo`.
- Empty-slot placeholders exist.

### Likely

- `CSaveGameList` stores separate arrays for names, file-info records, and index order.
- Folder names and other metadata are derived or cached in the GUI path, not necessarily stored as a single monolithic slot object.

### Unknown

- Exact semantic labels of the six time fields.
- Whether `folder`, `module name`, `module UUID`, `character`, `portrait`, and `preview` are persisted as fields inside `CSaveGameList` or reconstructed from the save directory by helper code.

# Why GetSaveGameFileInfo() is called twice

The call repetition is confirmed in the panel-side load flow:

- `CPanelLoadGame::SendLoadGameRequest()`
- `CPanelLoadGame::OnConnectServerStatusPanelExit(int)`

Both paths query save metadata through `CSaveGameList`, and `SendLoadGameRequest()` calls `GetSaveGameFileInfo(int)` twice before dispatching the native request.

## Evidence-based explanation

The most defensible explanation is:

1. `GetSaveGameFileInfo(int)` is an indexed out-parameter fill, not a pointer-returning accessor.
2. The panel code uses the same selected slot metadata in more than one step.
3. Re-reading the file-info object is therefore cheap and safe compared with caching an internal pointer whose lifetime is unclear.

## What is not proven

It is **not** proven that the two calls return different semantic fields.

It is also **not** proven that the second call is required for copy construction, validation, or resource registration.

Those are plausible explanations, but the binary evidence only supports "the same indexed metadata is fetched again."

# Comparison with current wrapper

## Native versus wrapper

| Native model | Current wrapper model | Status |
|---|---|---|
| save index | `R36S_SELECTED_SAVE_INDEX` | Confirmed match |
| save folder / directory name | `R36S_SELECTED_SAVE_FOLDER` | Confirmed match |
| display save name | `save_name` field in `r36s_saveindex.txt` | Confirmed match |
| save timestamp | `mtime` | Confirmed match |
| module name | `module_name` | Confirmed match |
| character name | `character_name` | Confirmed match |
| portrait resref | `portrait_resref` | Confirmed match |
| class name | `class_name` | Confirmed match |
| level | `level` | Confirmed match |
| preview screenshot | `r36s_preview.tga` staged separately | Wrapper supplies it, but not as a textual saveindex field |
| empty-slot placeholder | not yet modeled in the wrapper UI | Missing from wrapper model |
| native index/order mapping | wrapper currently displays one selected save and stores index 0 only | Partially modeled |
| module UUID handling | not yet exposed in the wrapper saveindex | Missing / not yet proven necessary |

## What the wrapper already does well

- The wrapper already produces a higher-level slot record than the native list requires.
- The wrapper already has the metadata needed for UI display.
- The wrapper already stages preview resources separately from the text saveindex.

## What the native model still has that the wrapper does not yet mirror

- empty-slot behavior
- explicit slot-order mapping
- native `CFileInfo` timestamp semantics

## What the wrapper likely does not need

- direct replication of the engine’s internal `CFileInfo` layout
- direct replication of the engine’s directory enumeration internals

The wrapper mainly needs to stay compatible with the fields the GUI and future loader will consume.

# Missing information

The main unresolved points are:

1. Exact meaning of the six `CFileInfo` time fields.
2. Exact field boundaries of the native save-slot object beyond the arrays inferred from `CSaveGameList`.
3. Whether `folder`, `module name`, `module UUID`, `character`, `portrait`, and `preview` are stored inside `CSaveGameList` or reconstructed by panel code.
4. Exact meaning of the four parameters to `SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`.
5. Whether the wrapper can influence load behavior via staging/restart without calling into the client/server pipeline.

# Recommended next experiment

Exactly one experiment gives the most information:

1. Perform one real native save load and watch `CURRENTGAME` and `TEMPCLIENT` before and after the load.

Why this is the best next step:

- It can show whether the engine stages files on disk as part of load.
- It may reveal whether a restart-and-stage strategy is viable.
- It avoids speculative hooking or implementation work before the file-system behavior is understood.