# Goal

Determine whether the current perf recording model can observe an already-running NWN process, given that the saved recording header shows `enable_on_exec = 1` and the helper records with `-- sleep 1d`.

# Current recording model

The earlier helper started perf like this:

```bash
sudo perf record -o "$PERF_DATA" -e "$PERF_EVENT_NAME" -- sleep 1d
```

Relevant helper code:

- [`dev/pc/scripts/host-trace-handle-select.sh`](../../pc/scripts/host-trace-handle-select.sh)

The perf help text documents the relevant modes:

- `-a, --all-cpus` is system-wide collection from all CPUs, and it is the default only if no target is specified.
- `-p, --pid=` records events on an existing process ID.

That means the earlier helper was not attaching perf to an existing NWN PID. It was keeping perf alive by running `sleep 1d` as the command target.

The helper has since been updated to use `perf record -p <nwmain-linux PID>`, which is the correct live-process model for the current end-to-end experiment runner.

# enable_on_exec analysis

The saved perf header for the successful probe installation showed:

```text
disabled = 1, inherit = 1, enable_on_exec = 1, sample_id_all = 1
```

The `perf_event_open(2)` man page says:

```text
enable_on_exec
     If this bit is set, a counter is automatically enabled after a
     call to execve(2).
```

So the probe event is created disabled and becomes enabled after an `execve()` in the task context that owns the perf session.

This is consistent with the earlier helper model:

- perf starts
- `sleep 1d` execs
- the event becomes enabled for that perf session

It does **not** automatically mean the already-running NWN process becomes the active target of the session.

# Effect on already-running NWN

The current recording model is at best indirect for an already-running NWN process, because:

1. the helper records against `sleep 1d`, not against the NWN PID
2. `inherit = 1` applies inheritance from the recorded task tree
3. the target NWN process was already running before perf started

Therefore the earlier setup could miss the existing NWN process even though the uprobe was installed and perf record was running.

The evidence supporting this is:

- helper command line: `perf record ... -- sleep 1d`
- perf header: `enable_on_exec = 1`
- `perf report` on the resulting `.data` said the file had no samples
- the decoded trace had no `probe_nwmain:nwn_handle_select` hits

This means the current recording mode is **not sufficient** for proving a hit in an already-running NWN process.

# Recommended minimal change

Do **not** keep using the `sleep 1d` task-targeted model for the live NWN trace.

The helper has now been updated to record against the actual `nwmain-linux` PID with `-p`, which is the correct fix for an already-running game process.

For reference, the minimal conceptual fix is to attach perf to the running NWN process instead of to `sleep`, for example:

- `perf record -p <nwmain-linux pid> -e "$PERF_EVENT_NAME"`

or, if system-wide capture is acceptable for this probe:

- `perf record -a -e "$PERF_EVENT_NAME" -- sleep 1d`

The first option is the most direct for an already-running NWN instance.

I am not implementing that change here; this note only documents why the previous model was insufficient and why the PID-attached model is preferred.
