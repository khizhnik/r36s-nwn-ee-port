# Goal

Reconstruct the logical algorithm of `CSaveGameList::GetSaveGameList()`.

This note is research-only. It does not implement anything.

# Existing evidence

## Environment inspected

- Repository: `~/Games/PortMaster/r36s-nwn-ee-port`
- Native binary inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-arm64/nwmain-linux`
- Previous notes referenced:
  - `dev/research/nui/Native-CSaveGameList-Data-Model.md`
  - `dev/research/nui/GetAugmentedDirectoryList-Analysis.md`

## Commands used

- `nm -C`
- `readelf -Ws`
- `objdump -d -C`
- `rg`
- `strings`
- `file`
- `ldd`

## Relevant symbols

- `CSaveGameList::GetSaveGameList()`
- `CSaveGameList::GetSaveGameName(int)`
- `CSaveGameList::GetSaveGameFileInfo(int)`
- `CSaveGameList::SortSaveGameList()`
- `CSaveGameList::InsertEmptySlot(int)`
- `CSaveGameList::CompareTwoTimes(CFileInfo*, CFileInfo*)`
- `CExoBase::GetDirectoryList(...)`
- `CExoBase::GetAugmentedDirectoryList(...)`
- `CExoBaseInternal::GetDirectoryList(...)`
- `CExoBaseInternal::GetAugmentedDirectoryList(...)`

# High-level algorithm

The best evidence-based reconstruction of `CSaveGameList::GetSaveGameList()` is:

1. Create a temporary save-root string.
2. Ask `CExoBase::GetDirectoryList()` for the list of save directories.
3. For each returned directory:
   1. Format a display/save name string from the directory entry.
   2. Build a per-save path string.
   3. Ask `CExoBase::GetAugmentedDirectoryList()` for file-info records inside that save folder.
   4. If the augmented helper says the slot is valid, append the data to the save-name and file-info arrays.
   5. If the helper indicates a gap or empty slot, insert placeholder slots with `InsertEmptySlot(int)`-style behavior.
4. Maintain an index/order mapping array.
5. Sort the list.

## Evidence for that order

- `GetSaveGameList()` calls `GetDirectoryList()` first.
- Inside the per-directory loop, it then calls `GetAugmentedDirectoryList()` on the save-folder path.
- `InsertEmptySlot(int)` exists and is used by the save-list machinery to preserve gaps.
- `SortSaveGameList()` is called after the list-building work is complete.

## What this is not

This is not a complete parse of save contents.

The disassembly does **not** show `GetSaveGameList()` itself reading:

- `savenfo.txt`
- `player.bic`
- `screen.tga`
- `module_uuid.txt`

So the algorithm below is the **native save-list construction algorithm**, not the complete save-content interpretation pipeline.

# Save metadata construction

## Where metadata begins

`GetSaveGameList()` itself begins with filesystem enumeration, not save semantics.

The first place where richer record construction appears is when it calls:

- `CExoBase::GetAugmentedDirectoryList(CExoArrayList<CFileInfo>*, CExoString, unsigned short, int)`

That helper produces `CFileInfo` records with timestamps and file metadata.

## What `GetSaveGameList()` adds on top

`GetSaveGameList()` turns generic file-info output into a save-slot model by:

- associating the directory entry with a save-name string
- storing the returned file-info record in its internal arrays
- keeping an index/order mapping
- inserting empty slots when needed
- sorting the final list

## What it does not prove

The current evidence does **not** prove that `GetSaveGameList()` itself understands:

- character name
- portrait
- preview screenshot
- module UUID
- module semantics

Those are handled later in the GUI selection/load path or by other helpers.

# Save object lifetime

## When is the internal object created?

The save-list object already exists before `GetSaveGameList()` is called.

Evidence:

- `CSaveGameList::CSaveGameList()` zeroes the internal arrays, then immediately calls `GetSaveGameList()` and `SortSaveGameList()`.

## When is it complete?

It becomes complete only after:

1. all save directories have been enumerated
2. per-directory file-info records have been gathered
3. empty-slot placeholders have been inserted where required
4. the list has been sorted

## Ownership

`CSaveGameList` owns the save-list arrays and the index mapping.

The GUI consumes the finished object; it does not appear to own the save list itself.

# Sorting

## Timing

Sorting occurs after the save list is populated.

Evidence:

- `CSaveGameList::CSaveGameList()` calls `GetSaveGameList()` and then `SortSaveGameList()`.
- `SortSaveGameList()` exists as a dedicated helper.

## Criteria

The sorting comparator is `CSaveGameList::CompareTwoTimes(CFileInfo*, CFileInfo*)`.

That comparator uses the time-like components stored in `CFileInfo`.

So the ordering criterion is:

- timestamp-driven, not filename-driven

## What is not proven

The exact semantic labels of the six timestamp fields are still not fully proven, but they are clearly time-like and used for ordering.

# GUI handoff

`GetSaveGameList()` does not appear to return a rich standalone save-slot object to the GUI.

Instead it mutates the `CSaveGameList` internal arrays, and the GUI later consumes the list through:

- `GetSaveGameName(int)`
- `GetSaveGameFileInfo(int)`

So the handoff is:

> build internal arrays first, query by index later

## Practical effect

The GUI gets:

- indexed save names
- indexed file-info records
- sorted order
- empty-slot placeholders

It does **not** appear to get a fully materialized “SaveSlot” value object from `GetSaveGameList()` itself.

# Comparison with wrapper

| Native step | Wrapper step | Equivalent? | Comments |
|---|---|---|---|
| Enumerate save directories | Scan `saves/` on the wrapper side | Equivalent | Both begin with filesystem enumeration. |
| Gather per-save file metadata | Parse save files on the wrapper side and stage `r36s_saveindex.txt` / preview resources | Different | Wrapper does more semantic parsing than `GetSaveGameList()` itself. |
| Build internal indexed list | Build one save-indexed record in `r36s_saveindex.txt` | Equivalent in spirit | Wrapper currently models one save slot explicitly, but not the native internal arrays. |
| Insert empty slots | Not yet modeled in the wrapper UI | Missing | Native list supports placeholder slots. |
| Sort by time | Wrapper can sort externally before writing | Better in wrapper | Wrapper has already lifted the semantics to a higher level. |
| GUI queries by index | NUI reads one selected record and uses indexed locals | Equivalent in spirit | The wrapper currently exposes one selected slot rather than the whole internal array model. |

# Remaining unknowns

## Confirmed

- `GetSaveGameList()` begins with directory enumeration.
- It then calls `GetAugmentedDirectoryList()` per save folder.
- It maintains a save-name array, a file-info array, and an index/order mapping.
- Sorting is timestamp-based.
- Empty-slot placeholders exist.

## Likely

- `GetSaveGameList()` is the point where directory entries become save slots.
- `GetAugmentedDirectoryList()` supplies the generic metadata that `CSaveGameList` turns into list entries.

## Unknown

- The exact condition under which `GetSaveGameList()` decides to call `InsertEmptySlot(int)`.
- The exact meaning of the `0x809` type value passed to `GetAugmentedDirectoryList()` in the save-list path.
- Whether `GetSaveGameList()` itself caches any save-specific fields beyond name and file-info records.
- The exact boundary between generic file metadata and save-specific semantics.

# Final conclusion

Have we reconstructed enough of `CSaveGameList` to understand the engine's save model?

**No.**

We have reconstructed enough to understand the **save-list construction algorithm**:

- directory enumeration
- per-folder file augmentation
- indexed storage
- empty-slot insertion
- time-based sorting
- GUI handoff by index

But we still do **not** have the full save semantics boundary.

What is still missing:

- where the engine turns save-folder contents into character/module/preview semantics
- how `module_uuid.txt`, `player.bic`, `screen.tga`, and `savenfo.txt` are interpreted in the full pipeline
- whether those semantics are resolved in `CSaveGameList`, panel code, or deeper helpers

# Recommended next experiment

Exactly one experiment follows naturally:

1. Trace the first caller that turns the generic save list into save-specific metadata, then inspect whether it reads `module_uuid.txt`, `player.bic`, or `screen.tga`.

Why this is the best next step:

- `GetSaveGameList()` itself is now understood at the architecture level.
- The remaining uncertainty is the boundary where generic file metadata becomes NWN save semantics.
- That boundary is the last major unknown before attempting native save integration.