# Goal

Verify the three new probes individually:

1. `CPanelLoadSave::HandleSelectSaveGame(int)`
2. `CExoResMan::AddResourceDirectory(...)`
3. `CNWPortrait::ReplacePortraitTexture(...)`

The ideal per-symbol checklist was:

- `perf probe --definition`
- resolved offset
- add succeeds
- appears in `perf probe -l`
- remove succeeds

This environment could confirm the symbol resolution part, but privileged probe install/list/remove was blocked by container `no_new_privileges`.

# Files analyzed

- `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- `dev/pc/scripts/host-trace-handle-select.sh`
- `dev/research/runtime/First-EndToEnd-HandleSelectSaveGame-Run.md`
- `dev/research/runtime/Steam-Original-HandleSelectSaveGame-Trace.md`

# Symbol 1: CPanelLoadSave::HandleSelectSaveGame

`perf probe --definition`:

```text
p:probe_nwmain/nwn_handle_select ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux:0x6fd500
```

Resolved offset:

- `0x6fd500`

`nm -C` confirms the symbol address:

```text
00000000006fd500 T CPanelLoadSave::HandleSelectSaveGame(int)
```

Add succeeds?

- Not verifiable in this container session because `sudo` is blocked by `no new privileges`

Appears in `perf probe -l`?

- Not verifiable in this container session for the same reason

Remove succeeds?

- Not verifiable in this container session for the same reason

# Symbol 2: CExoResMan::AddResourceDirectory

`perf probe --definition`:

```text
p:probe_nwmain/nwn_add_res_dir ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux:0x53bac0
```

Resolved offset:

- `0x53bac0`

`nm -C` confirms the symbol address:

```text
000000000053bac0 T CExoResMan::AddResourceDirectory(CExoString const&, unsigned int, int, bool (*)(CExoKeyTable*, CResRef const&, unsigned short))
```

Add succeeds?

- Not verifiable in this container session because `sudo` is blocked by `no new privileges`

Appears in `perf probe -l`?

- Not verifiable in this container session for the same reason

Remove succeeds?

- Not verifiable in this container session for the same reason

# Symbol 3: CNWPortrait::ReplacePortraitTexture

`perf probe --definition`:

```text
p:probe_nwmain/nwn_replace_portrait ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux:0x81f240
```

Resolved offset:

- `0x81f240`

`nm -C` confirms the symbol address:

```text
000000000081f240 T CNWPortrait::ReplacePortraitTexture(CAurObject*, CResRef const&)
```

Add succeeds?

- Not verifiable in this container session because `sudo` is blocked by `no new privileges`

Appears in `perf probe -l`?

- Not verifiable in this container session for the same reason

Remove succeeds?

- Not verifiable in this container session for the same reason

# Notes

- The target binary resolves all three symbols consistently with `nm -C` and `perf probe --definition`.
- The helper script already encodes these three stable event names:
  - `nwn_handle_select`
  - `nwn_add_res_dir`
  - `nwn_replace_portrait`
- In this container, direct privileged verification was blocked before `perf probe --add`, `perf probe -l`, and `perf probe --del` could be exercised.

# Conclusion

The symbol-resolution part of the verification is confirmed for all three probes.

The privileged install/list/remove steps could not be completed in this container session because `sudo` is blocked by `no new privileges`.

Final status:

**PARTIAL VERIFICATION**

