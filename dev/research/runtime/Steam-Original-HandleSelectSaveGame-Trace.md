# Goal

Analyze the latest Steam-launched original NWN perf trace and determine whether `probe_nwmain:nwn_handle_select` actually fired.

# Files analyzed

- `dev/pc/logs/host-trace-handle-select-20260702-202606.setup.log`
- `dev/pc/logs/host-trace-handle-select-20260702-202606.perf-record.log`
- `dev/pc/logs/host-trace-handle-select-20260702-202606.data`
- `dev/pc/logs/host-trace-handle-select-20260702-202606.txt`

# Probe setup

The setup log shows the probe was installed successfully:

```text
Added new event:
  probe_nwmain:nwn_handle_select (on 0x6fd500 in /tmp/nwmain-linux-hardlink)
```

The setup log also records the probe listing and cleanup:

```text
PROBE_LIST:   probe_nwmain:nwn_handle_select (on CPanelLoadSave::HandleSelectSaveGame in /tmp/nwmain-linux-hardlink)
CREATED_PROBE: probe_nwmain:nwn_handle_select
Cleanup: perf probe --del succeeded for probe_nwmain:nwn_handle_select
Cleanup: removed hardlink /tmp/nwmain-linux-hardlink
```

This confirms the uprobe was created on the hardlink inode used by the helper.

# perf data decoding

`perf script -f -i dev/pc/logs/host-trace-handle-select-20260702-202606.data --header-only` shows:

```text
# cmdline : /usr/bin/perf record -o ~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/logs/host-trace-handle-select-20260702-202606.data -e probe_nwmain:nwn_handle_select -- sleep 1d
# event : name = probe_nwmain:nwn_handle_select, , id = { ... }, type = 2, size = 128, config = 0xad0, { sample_period, sample_freq } = 1, sample_type = IP|TID|TIME|CPU|PERIOD|RAW|IDENTIFIER, read_format = ID|LOST, disabled = 1, inherit = 1, enable_on_exec = 1, sample_id_all = 1, exclude_guest = 1
# event : name = dummy:HG, , id = { ... }, type = 1, size = 128, config = 0x9, { sample_period, sample_freq } = 1, sample_type = IP|TID|TIME|IDENTIFIER, read_format = ID|LOST, inherit = 1, mmap = 1, comm = 1, task = 1, sample_id_all = 1, mmap2 = 1, comm_exec = 1, ksymbol = 1, bpf_event = 1
```

The header also shows:

- `time of first sample : 0.000000`
- `time of last sample : 0.000000`

`perf report -f -i dev/pc/logs/host-trace-handle-select-20260702-202606.data --stdio` says:

```text
Error:
The dev/pc/logs/host-trace-handle-select-20260702-202606.data data has no samples!
```

`perf script -f -i dev/pc/logs/host-trace-handle-select-20260702-202606.data` produced no sample records.

# Hits

There are no observed hits for `probe_nwmain:nwn_handle_select`.

Evidence:

- `perf report` says the `.data` file has no samples
- `perf script` prints nothing for sample records
- the `.txt` output file is empty

Because there are no samples, there are no timestamps, pids, tids, CPUs, or callchains to list.

# Comparison with bootstrap trace

The Steam/original NWN trace matches the earlier bootstrap/NUI trace in the important way:

- the probe is present in metadata
- the recording completed and produced a `.data` file
- but there are no sample hits

The difference is that this run removes custom NUI from the explanation. The original Steam binary still produced no sample hit under the current recording model.

The strongest evidence-based explanation is that the recording model is still wrong for the active game process:

- the helper records against `sleep 1d`
- the perf header shows `enable_on_exec = 1`
- the event therefore becomes active for the `sleep` exec/session, not automatically for an already-running unrelated NWN process

Wrong binary/inode is unlikely here because the setup log confirms the probe was created on the hardlinked inode that resolves to the original binary content.

This trace should therefore be treated as a control for the deprecated sleep-based model. It is useful as evidence that the probe itself works, but it should be repeated later with `--no-launch` or the new PID-attached helper to test the live Steam process.

# Conclusion

This trace contains perf metadata only and no sample hits.

Final status:

**STEAM TRACE NO HIT OBSERVED**

Evidence:

- `perf report` says the data file has no samples
- `perf script` produced no sample records
- `probe_nwmain:nwn_handle_select` appears only in the header metadata, not as an observed runtime hit
