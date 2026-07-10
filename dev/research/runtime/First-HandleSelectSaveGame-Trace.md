# File information

- `dev/pc/logs/host-trace-handle-select-20260702-194931.data`
  - size: `78321` bytes
  - captured timestamp: `2026-07-02 19:58:01`
- `dev/pc/logs/host-trace-handle-select-20260702-194931.setup.log`
  - size: `1211` bytes
- `dev/pc/logs/host-trace-handle-select-20260702-194931.perf-record.log`
  - size: `200` bytes
- `dev/pc/logs/host-trace-handle-select-20260702-194931.txt`
  - size: `0` bytes

# perf script output

`perf script -f -i dev/pc/logs/host-trace-handle-select-20260702-194931.data` produced no sample records.

`perf report -f -i dev/pc/logs/host-trace-handle-select-20260702-194931.data --stdio` reported:

```text
Error:
The dev/pc/logs/host-trace-handle-select-20260702-194931.data data has no samples!
```

# perf report output

`perf report` confirms there are no samples in the file.

Relevant log line:

```text
The dev/pc/logs/host-trace-handle-select-20260702-194931.data data has no samples!
```

# Events present

The file header contains these event definitions:

```text
# event : name = probe_nwmain:nwn_handle_select, , id = { 301, 302, ... }, type = 2, size = 128, config = 0xace, { sample_period, sample_freq } = 1, sample_type = IP|TID|TIME|CPU|PERIOD|RAW|IDENTIFIER, read_format = ID|LOST, disabled = 1, inherit = 1, enable_on_exec = 1, sample_id_all = 1, exclude_guest = 1
# event : name = dummy:HG, , id = { 321, 322, ... }, type = 1, size = 128, config = 0x9, { sample_period, sample_freq } = 1, sample_type = IP|TID|TIME|IDENTIFIER, read_format = ID|LOST, inherit = 1, mmap = 1, comm = 1, task = 1, sample_id_all = 1, mmap2 = 1, comm_exec = 1, ksymbol = 1, bpf_event = 1
```

So the event types present in the recording metadata are:

- `probe_nwmain:nwn_handle_select`
- `dummy:HG`

No decoded sample events are present.

# Probe hits

There are no probe hits in the decoded trace output.

Evidence:

- `perf script -f` emitted no sample lines
- `perf report` says the data file has no samples

Therefore:

- `probe_nwmain:nwn_handle_select` appears in the metadata, but **not** as an observed runtime hit
- no timestamps, pids, tids, CPUs, or callchains were recorded as sample output

# Interpretation

The file is ~78 KB because it contains perf header metadata, event definitions, build-id and topology information, and other recording metadata even though no samples were produced.

The strongest evidence-based explanation for the absence of probe hits is:

- the recording session completed, but no `probe_nwmain:nwn_handle_select` sample was generated during the tracing window
- `perf report` confirms the file has no samples at all, so there was nothing for `perf script` to decode

Nearby runtime functions such as `CPanelLoadGame::...`, `CPanelLoadSave::...`, `CExoResMan::...`, or `CNWSaveGame::...` do not appear because there are no sample records to inspect.

# Conclusion

The recording contains metadata but no samples.

Final status:

**NO PROBE HIT OBSERVED**

Evidence:

- `perf report` says the data file has no samples
- `perf script -f` produced no sample lines
- therefore there is no evidence that `probe_nwmain:nwn_handle_select` fired
