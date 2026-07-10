# Goal

Determine what `CExoBase::GetAugmentedDirectoryList()` adds beyond `GetDirectoryList()`, and whether it is the point where native save semantics begin.

This note is research-only. It does not implement anything.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Native binary inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- Previous notes referenced:
  - `dev/research/nui/Native-CSaveGameList-Data-Model.md`
  - `dev/research/nui/Native-Load-Game-Message-Flow.md`

## Commands used

- `nm -C`
- `readelf -Ws`
- `objdump -d -C`
- `rg`
- `strings`
- `file`
- `ldd`

## Relevant symbol addresses found on x86

- `CExoBase::GetDirectoryList(CExoArrayList<CExoString>*, CExoString, unsigned short, int, int, int)` at `0x4dcb60`
- `CExoBase::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)` at `0x4dcdb0`
- `CExoBaseInternal::GetDirectoryList(CExoArrayList<CExoString>*, CExoString, unsigned short, int, int)` at `0x50b090`
- `CExoBaseInternal::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)` at `0x50b890`

## Relevant symbol addresses found on ARM64

- `CExoBase::GetDirectoryList(CExoArrayList<CExoString>*, CExoString, unsigned short, int, int, int)` at `0x508310`
- `CExoBase::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)` at `0x508520`
- `CExoBaseInternal::GetDirectoryList(CExoArrayList<CExoString>*, CExoString, unsigned short, int, int)` at `0x533f00`
- `CExoBaseInternal::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)` at `0x5344e8`

# Exported symbols

## `CExoBase::GetDirectoryList(...)`

Thin wrapper over `CExoBaseInternal::GetDirectoryList(...)`.

## `CExoBase::GetAugmentedDirectoryList(...)`

Thin wrapper over `CExoBaseInternal::GetAugmentedDirectoryList(...)`.

## `CExoBaseInternal::GetDirectoryList(...)`

Implements directory enumeration.

## `CExoBaseInternal::GetAugmentedDirectoryList(...)`

Implements file enumeration plus metadata augmentation.

# GetDirectoryList algorithm

The x86 disassembly shows a generic directory enumerator:

1. Saves the current working directory with `getcwd()`.
2. Changes directory to the requested root with `chdir()`.
3. Opens the directory with `opendir()`.
4. Iterates entries with `readdir64()`.
5. Skips dot entries and applies directory filtering with `__xstat64()`.
6. Converts each accepted entry into a `CExoString`.
7. Inserts the string into a `CExoArrayList<CExoString>`.
8. Restores the original working directory with `chdir()`.

## Evidence

- `GetDirectoryList()` uses `opendir`, `readdir64`, `__xstat64`, `strcmp`, `CExoString::InitFromCharArray`, and `CExoArrayList<CExoString>::Add/Insert`.
- The helper is used by many unrelated systems:
  - `CSaveGameList::GetSaveGameList()`
  - `CExoResMan::WipeDirectory(...)`
  - `CCharacterList::CCharacterList()`
  - `CServerExoAppInternal::LoadModule(...)`
  - `ContentIndex::LocalDiscoveryAliasRepository::SetupData(...)`
  - `ContentIndex::SteamWorkshopDiscoveryRepository::SetupData(...)`
  - `CNWSMessage::HandleServerToServerAdmin...` paths

This makes `GetDirectoryList()` clearly a general-purpose filesystem helper.

# GetAugmentedDirectoryList algorithm

The x86 disassembly shows that the augmented helper does more than plain directory enumeration, but still remains generic filesystem logic.

## Step-by-step algorithm

1. Save current working directory with `getcwd()`.
2. Resolve the provided path through `CExoAliasList::ResolveFileName(...)`.
3. Switch to the resolved directory with `chdir()`.
4. Open the directory with `opendir()`.
5. Fetch a resource-extension string from the requested resource type using `GetResourceExtension(unsigned short)`.
6. Iterate entries with `readdir64()`.
7. Skip dot entries and skip subdirectories after `__xstat64()` shows `S_IFDIR`.
8. Build a file path string from the current entry.
9. Convert file timestamps to local time with `localtime()`.
10. Fill six 16-bit time fields in a temporary `CFileInfo`-like record.
11. Copy the file name/path string into the record.
12. Add the record to `CExoArrayList<CFileInfo>` with `CExoArrayList<CFileInfo>::Add(CFileInfo)`.
13. Restore the original working directory with `chdir()`.

## What it adds beyond `GetDirectoryList()`

Compared with `GetDirectoryList()`, the augmented helper additionally performs:

- alias/path resolution
- resource-extension lookup from the requested type
- per-entry `__xstat64()` inspection
- timestamp conversion with `localtime()`
- construction of `CFileInfo` records

## What it does not show

The disassembly does **not** show direct parsing of save-specific files such as:

- `savenfo.txt`
- `player.bic`
- `screen.tga`
- `module_uuid.txt`

There is no direct evidence in the helper body that it understands NWN save semantics.

## Algorithmic summary

`GetAugmentedDirectoryList()` is best understood as:

> filesystem enumeration + path resolution + resource-type-aware filtering + timestamp augmentation

It is **not** proven to be a save-aware parser.

# Differences

| Operation | DirectoryList | AugmentedDirectoryList |
|---|---|---|
| Filesystem enumeration | Yes | Yes |
| Metadata extraction | Minimal, directory names only | Yes, per-file metadata into `CFileInfo` |
| Timestamp handling | Not exposed in the helper body | Yes, via `__xstat64()` and `localtime()` |
| Extra allocations | Temporary string arrays | Temporary strings plus `CFileInfo` records |
| Helper calls | `getcwd`, `chdir`, `opendir`, `readdir64`, `strcmp`, `__xstat64` | `getcwd`, `chdir`, `opendir`, `readdir64`, `ResolveFileName`, `GetResourceExtension`, `__xstat64`, `localtime`, `CExoArrayList<CFileInfo>::Add` |
| Sorting | Appears to insert in sorted order by string compare | No independent save sorting shown; the caller may sort later |
| Other | Generic directory listing | Generic file listing with richer file attributes/time info |

## Interpretation

The key difference is not “directories vs saves”.

The difference is:

- `GetDirectoryList()` produces a list of directory names.
- `GetAugmentedDirectoryList()` produces a list of `CFileInfo` records for files inside a directory, with time metadata attached.

# CFileInfo reconstruction

The `CFileInfo` object is only partially recoverable from the disassembly, but the confirmed fields are enough to describe the augmentation model.

## Confirmed fields

| Field | Status | Evidence |
|---|---|---|
| String-like payload | Confirmed | `GetSaveGameFileInfo(int)` copies a string-like field at offset `0x0` with a length/auxiliary field at `0x8`. |
| Six 16-bit time fields | Confirmed | `CompareTwoTimes(CFileInfo*, CFileInfo*)` compares six `uint16` values in sequence; `GetAugmentedDirectoryList()` fills them from `localtime()`. |

## Likely fields

| Field | Status | Evidence |
|---|---|---|
| Filename or full path | Likely | `GetAugmentedDirectoryList()` builds a per-entry file string and stores it in the record. |
| Timestamp components | Likely | The six 16-bit fields are filled from `tm_year`, `tm_mon`, `tm_mday`, `tm_hour`, `tm_min`, `tm_sec`. |
| Resource-type-derived handling | Likely | The helper resolves a resource extension from the requested type before scanning. |

## Unknown fields

| Field | Status | Evidence |
|---|---|---|
| File size | No evidence | No clear store/use pattern found in the helper body. |
| File attributes/flags | No evidence | Not observed in the recoverable portion of the record writes. |
| Directory flag | No evidence | The helper skips directories rather than storing them. |
| Save semantics | No evidence | No save-specific parsing appears in the helper body. |

# Ownership analysis

## Who creates save metadata?

### Filesystem

Confirmed to create the raw entry list.

- `GetDirectoryList()` enumerates directories.
- `GetAugmentedDirectoryList()` enumerates files and collects timestamps.

### AugmentedDirectoryList

Confirmed to create generic file metadata records.

- It produces `CFileInfo` records.
- It computes time fields from file timestamps.

### CSaveGameList

Confirmed to interpret the augmented file data as a save list.

- It requests directory enumeration.
- It requests augmented file-info lists.
- It stores and sorts the resulting save list.

### GUI

The GUI consumes the save-list output.

- `CPanelLoadSave::PopulateListWithSaveDirContents()`
- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadGame::SendLoadGameRequest()`

### Other

`CNWSMessage::SendServerToServerAdminSaveGameList(unsigned int)` also calls `GetAugmentedDirectoryList()`.

That is important evidence that the helper is not save-only.

# Callers

## `GetAugmentedDirectoryList()`

Callers found in the x86 binary scan:

1. `CSaveGameList::GetSaveGameList()`
2. `CNWSMessage::SendServerToServerAdminSaveGameList(unsigned int)`

## `GetDirectoryList()`

This helper is used far more broadly, including:

- `CSaveGameList::GetSaveGameList()`
- `CExoResMan::WipeDirectory(...)`
- `CCharacterList::CCharacterList()`
- `CServerExoAppInternal::LoadModule(...)`
- `ContentIndex::LocalDiscoveryAliasRepository::SetupData(...)`
- `ContentIndex::SteamWorkshopDiscoveryRepository::SetupData(...)`
- `CNWSMessage::HandleServerAdminToServerMessage(unsigned int, unsigned char*, unsigned int)`
- `CNWSMessage::SendServerToServerAdminSaveGameList(unsigned int)`

That wider reuse supports the conclusion that the underlying helper family is general-purpose filesystem logic.

# Comparison with wrapper

## Native

- `GetDirectoryList()`:
  - directory names only
- `GetAugmentedDirectoryList()`:
  - file records
  - timestamps
  - resource-type-aware path handling
- `CSaveGameList`:
  - builds the save model from that data
- GUI:
  - turns the model into load/save UI

## Wrapper

Current wrapper output already exceeds the native augmentation in save semantics:

- save name
- folder
- area
- mtime
- module name
- character name
- portrait resref
- class name
- level
- preview screenshot staged separately

## Field-by-field comparison

| Field | Native augmentation | Wrapper |
|---|---|---|
| Directory / file entry name | Confirmed | Confirmed |
| Timestamp | Confirmed | Confirmed |
| Folder name | Not proven in helper body | Confirmed |
| Save name | Not proven in helper body | Confirmed |
| Area | Not proven in helper body | Confirmed |
| Module name | Not proven in helper body | Confirmed |
| Character name | Not proven in helper body | Confirmed |
| Portrait resref | Not proven in helper body | Confirmed |
| Preview screenshot | Not proven in helper body | Confirmed as staged resource |
| Class / level | Not proven in helper body | Confirmed |

## Interpretation

The wrapper is richer in **save semantics**.

The native augmentation is richer than a bare directory listing, but it is still fundamentally **filesystem metadata**, not a completed save-slot description.

# Final conclusion

“Augmented” does **not** appear to mean “save semantics”.

Based on the helper body and call sites, it means:

> filesystem enumeration + alias resolution + resource-type-aware file handling + timestamp augmentation

So the answer is:

- **Not just plain filenames**
- **Not yet NWN save semantics**

`GetAugmentedDirectoryList()` is part of the lower-level filesystem metadata layer. The save semantics begin later, in `CSaveGameList` and the load/save panel code.

# Recommended next experiment

Exactly one experiment follows naturally from this evidence:

1. Inspect the actual caller data passed from `CSaveGameList::GetSaveGameList()` into `GetAugmentedDirectoryList()` to see which resource type and path are used for save folders.

Why this is the best next step:

- It can confirm whether save scanning is using the helper as a generic file-info enumerator or as a save-folder-specific convention.
- It would also reveal whether the helper is asked to enumerate “all files” or a specific resource type when save folders are scanned.