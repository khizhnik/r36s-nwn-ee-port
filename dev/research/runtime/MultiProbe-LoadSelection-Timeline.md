# Goal

Analyze the fresh multi-probe trace run and determine how the three lifecycle probes behave together:

- `probe_nwmain:nwn_handle_select`
- `probe_nwmain:nwn_add_res_dir`
- `probe_nwmain:nwn_replace_portrait`

# Files analyzed

- `dev/pc/logs/host-trace-handle-select-20260702-213101.setup.log`
- `dev/pc/logs/host-trace-handle-select-20260702-213101.perf-record.log`
- `dev/pc/logs/host-trace-handle-select-20260702-213101.data`
- `dev/pc/logs/host-trace-handle-select-20260702-213101.txt`

# Probe setup

The setup log shows all three probes were installed successfully on the hardlinked NWN binary path:

```text
CREATED_PROBE[0]: probe_nwmain:nwn_handle_select
CREATED_PROBE[1]: probe_nwmain:nwn_add_res_dir
CREATED_PROBE[2]: probe_nwmain:nwn_replace_portrait
```

The resolved offsets were:

- `CPanelLoadSave::HandleSelectSaveGame(int)` -> `0x6fd500`
- `CExoResMan::AddResourceDirectory(...)` -> `0x53bac0`
- `CNWPortrait::ReplacePortraitTexture(...)` -> `0x81f240`

The probe install remained valid during the recording window and was cleaned up afterward:

```text
Cleanup: perf probe --del succeeded for probe_nwmain:nwn_handle_select
Cleanup: perf probe --del succeeded for probe_nwmain:nwn_add_res_dir
Cleanup: perf probe --del succeeded for probe_nwmain:nwn_replace_portrait
Cleanup: removed hardlink /tmp/nwmain-linux-hardlink
```

# Recording

The helper discovered and attached to the real NWN PID:

```text
ACCEPTED_PID: 2900790
ACCEPTED_EXE: ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux
ACCEPTED_INODE: 6058891
PERF_RECORD_CMD: sudo perf record -o '~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/logs/host-trace-handle-select-20260702-213101.data' -e 'probe_nwmain:nwn_handle_select' -e 'probe_nwmain:nwn_add_res_dir' -e 'probe_nwmain:nwn_replace_portrait' -p '2900790'
```

The perf log shows the recording was active and captured data:

```text
[ perf record: Woken up 1 times to write data ]
[ perf record: Captured and wrote 0.301 MB ~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/logs/host-trace-handle-select-20260702-213101.data (125 samples) ]
```

# Hit counts

`perf report --stdio` reports:

- `probe_nwmain:nwn_handle_select` - 11 samples
- `probe_nwmain:nwn_add_res_dir` - 15 samples
- `probe_nwmain:nwn_replace_portrait` - 99 samples

No event has zero hits in this run.

# Timeline

Chronological probe sequence from `perf script`:

1. `3118483.170204` - `probe_nwmain:nwn_add_res_dir` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144b93bac0`
2. `3118483.170282` - `probe_nwmain:nwn_add_res_dir` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144b93bac0`
3. `3118483.170326` - `probe_nwmain:nwn_add_res_dir` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144b93bac0`
4. `3118483.182157` - `probe_nwmain:nwn_add_res_dir` - pid `2900790`, tid `2900790`, cpu `011`, ip `56144b93bac0`
5. `3118483.197578` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
6. `3118483.200053` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
7. `3118483.200192` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
8. `3118483.200311` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
9. `3118483.200444` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
10. `3118483.200577` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
11. `3118483.200694` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
12. `3118483.200826` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
13. `3118483.200966` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
14. `3118483.201088` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
15. `3118483.201219` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
16. `3118483.201343` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
17. `3118483.201476` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
18. `3118483.201592` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
19. `3118483.201708` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
20. `3118483.201847` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
21. `3118483.201974` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
22. `3118483.202107` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
23. `3118483.202229` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
24. `3118483.202349` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
25. `3118483.202486` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
26. `3118483.202605` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
27. `3118483.202725` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
28. `3118483.202906` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
29. `3118483.203067` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`
30. `3118483.203196` - `probe_nwmain:nwn_replace_portrait` - pid `2900790`, tid `2900790`, cpu `004`, ip `56144bc1f240`

The full trace contains many more `probe_nwmain:nwn_replace_portrait` hits beyond the first 30 lines shown above. The important ordering evidence is:

- `CExoResMan::AddResourceDirectory` fires during startup and around the selection path
- `CNWPortrait::ReplacePortraitTexture` fires heavily during startup and again during selection
- `CPanelLoadSave::HandleSelectSaveGame` appears when the selection action is performed

Representative selection-path ordering from the decoded trace:

```text
3118489.415730: probe_nwmain:nwn_handle_select
3118489.415734: probe_nwmain:nwn_add_res_dir
3118489.415773: probe_nwmain:nwn_replace_portrait
```

This sequence clearly appears in the trace and is the strongest evidence for the selection lifecycle order.

# Lifecycle interpretation

The observed lifecycle is:

1. the UI selection triggers `HandleSelectSaveGame`
2. the engine then adds or refreshes a resource directory
3. portrait replacement follows immediately after

The trace also shows earlier startup-time `AddResourceDirectory` and `ReplacePortraitTexture` activity before the explicit selection event. That means those two probes are not exclusive to the selection click; they also occur during normal UI startup and refresh.

# Comparison with single-probe run

Compared to the first end-to-end single-probe run:

- the same `HandleSelectSaveGame` event is still confirmed
- the multi-probe run adds direct evidence for resource-directory and portrait refresh activity around the same interaction
- the PID attach model remains correct
- the multi-probe run shows a richer lifecycle with 125 total samples instead of 11 handle-select samples alone

The key new information is the relative ordering of the three probes during selection:

`HandleSelectSaveGame` -> `AddResourceDirectory` -> `ReplacePortraitTexture`

# Conclusion

The multi-probe trace succeeded.

All three probes fired, all three produced samples, and the selection-path ordering appears in the decoded trace.

Final status:

**MULTIPROBE SUCCESS**