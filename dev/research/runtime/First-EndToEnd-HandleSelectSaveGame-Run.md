# Environment

- Host: `13DEV`
- OS: `6.1.0-48-amd64`
- perf version: `6.1.174`
- Architecture: `x86_64`
- Target PID: `2895560`
- Probe event: `probe_nwmain:nwn_handle_select`

# Probe installation

The setup log shows the probe was installed successfully on the hardlinked NWN binary path:

```text
Added new event:
  probe_nwmain:nwn_handle_select (on 0x6fd500 in /tmp/nwmain-linux-hardlink)
```

The probe listing confirms the created event name:

```text
PROBE_LIST:   probe_nwmain:nwn_handle_select (on CPanelLoadSave::HandleSelectSaveGame in /tmp/nwmain-linux-hardlink)
CREATED_PROBE: probe_nwmain:nwn_handle_select
```

The helper discovered the real `nwmain-linux` PID by inode and attached perf to that PID:

```text
ACCEPTED_PID: 2895560
ACCEPTED_EXE: ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux
ACCEPTED_INODE: 6058891
PERF_RECORD_CMD: sudo perf record -o '~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/logs/host-trace-handle-select-20260702-210756.data' -e 'probe_nwmain:nwn_handle_select' -p '2895560'
```

The probe stayed installed during recording and was removed during cleanup:

```text
Cleanup: perf probe --del succeeded for probe_nwmain:nwn_handle_select
Cleanup: removed hardlink /tmp/nwmain-linux-hardlink
```

# Recording

The perf record log confirms recording ran and produced data:

```text
[ perf record: Woken up 1332 times to write data ]
[ perf record: Captured and wrote 0.190 MB ~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/logs/host-trace-handle-select-20260702-210756.data (5 samples) ]
```

The helper also logged that `perf record` exited before Ctrl+C:

```text
PERF_RECORD_EARLY_EXIT: perf record ended before Ctrl+C
PERF_RECORD_WAIT_RC: 0
```

That means the recording process ended cleanly after collecting the samples.

# Samples

The `.data` file contains 5 samples of `probe_nwmain:nwn_handle_select`.

`perf report --stdio` shows:

```text
Samples: 5  of event 'probe_nwmain:nwn_handle_select'
Event count (approx.): 5
```

`perf script` decoded the hits as:

```text
nwmain-linux 2895560 [009] 3117102.045659: probe_nwmain:nwn_handle_select: (55f0294fd500)
nwmain-linux 2895560 [008] 3117102.895637: probe_nwmain:nwn_handle_select: (55f0294fd500)
nwmain-linux 2895560 [010] 3117126.382078: probe_nwmain:nwn_handle_select: (55f0294fd500)
nwmain-linux 2895560 [003] 3117127.289483: probe_nwmain:nwn_handle_select: (55f0294fd500)
nwmain-linux 2895560 [003] 3117127.474558: probe_nwmain:nwn_handle_select: (55f0294fd500)
```

Metadata confirms:

- event type: `probe_nwmain:nwn_handle_select`
- sample type includes `IP|TID|TIME|CPU|PERIOD|RAW|IDENTIFIER`
- lost samples: `0`
- enable_on_exec: `1`
- attach mode: `-p 2895560`

# Function hits

The probe fired 5 times.

Observed hits:

1. `3117102.045659`, pid `2895560`, tid `2895560`, cpu `009`
2. `3117102.895637`, pid `2895560`, tid `2895560`, cpu `008`
3. `3117126.382078`, pid `2895560`, tid `2895560`, cpu `010`
4. `3117127.289483`, pid `2895560`, tid `2895560`, cpu `003`
5. `3117127.474558`, pid `2895560`, tid `2895560`, cpu `003`

No callchain was shown in the decoded text, so only the probe hit line itself is available.

The report associates the samples with:

```text
100.00%  nwmain-linux  nwmain-linux   [.] CPanelLoadSave::HandleSelectSaveGame
```

# Comparison with previous runs

Previous bootstrap/NUI and Steam/original trace runs had the same probe installed but no samples in the recording window.

Key difference in this successful run:

- perf was attached to the actual `nwmain-linux` PID with `-p 2895560`
- the helper discovered and stabilized the real game PID before recording
- the earlier sleep-based model is no longer used for this run

This run therefore removes the main uncertainty from the earlier traces:

- the probe exists
- perf is attached to the actual game process
- the function is hit during user interaction

# Conclusion

The first end-to-end tracing run succeeded.

The trace contains 5 hits of `probe_nwmain:nwn_handle_select`, and `perf report` attributes them to `CPanelLoadSave::HandleSelectSaveGame`.

Final status:

**SUCCESS**

The original hypothesis:

> Selecting a save executes `CPanelLoadSave::HandleSelectSaveGame`

is now:

**CONFIRMED**

