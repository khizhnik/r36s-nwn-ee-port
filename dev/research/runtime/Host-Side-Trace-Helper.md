# Goal

Provide a host-side passive tracing helper for the first NWN runtime observation:

- observe the small save-selection lifecycle set:
  - `CPanelLoadSave::HandleSelectSaveGame(int)`
  - `CExoResMan::AddResourceDirectory(...)`
  - `CNWPortrait::ReplacePortraitTexture(...)`
- use `perf` only
- keep the probe temporary and self-cleaning
- launch the PC harness itself by default and attach perf to the actual `nwmain-linux` PID

# What the helper does

The script:

1. Verifies the project root and the NWN x86 binary path.
2. Checks that `sudo` is available.
3. Creates a temporary hardlink in `/tmp` so the tracefs path has no spaces.
4. Records the original and hardlink inode numbers.
5. Resolves each function to a concrete offset with `perf probe --definition`.
6. Tries `perf probe -x "$TRACE_NWN_BIN" --add` for each stable event name and offset.
7. If perf returns `Invalid argument`, falls back to a direct tracefs write using the hardlink path.
8. Uses `perf probe -l` to discover the actual event name for each probe.
9. Trims leading whitespace from the `perf probe -l` output before extracting each event name.
10. Refuses to start `perf record` if any parsed event name is still empty.
11. In default mode, launches the PC harness itself.
12. Discovers the real `nwmain-linux` PID by inode.
13. Starts `perf record` against that PID with `-p`, not `sleep 1d`.
14. Prints instructions for the manual game interaction.
15. Waits for you to press `Ctrl+C`.
16. Converts the perf data into text with `perf script`.
17. Removes the temporary probe, temporary hardlink, and helper-launched child processes.
18. Prints the output paths.

# How to run it

From the project root, in a normal host terminal where `sudo` works:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh
```

# Manual actions required

While the helper is running:

1. Open the PC harness in another terminal if it is not already running.
2. Open the Load screen.
3. Select exactly one save.
4. Return to the tracing terminal.
5. Press `Ctrl+C` to stop tracing.

# How to know success

The first success marker is the function name appearing in the generated perf script output.

Expected success evidence:

- the trace text file is created
- the trace contains entries for `CPanelLoadSave::HandleSelectSaveGame`

The helper now discovers the exact created event names with `perf probe -l`, discovers the actual `nwmain-linux` PID, waits for that PID to stabilize, and uses `perf record -p <pid>` for recording.

The helper now uses a hardlink-based setup:

1. create `/tmp/nwmain-linux-hardlink` pointing to the original binary inode
2. resolve the function into a concrete `0x...` offset with `perf probe --definition`
3. add the probe against the hardlink path
4. if perf rejects the add with `Invalid argument`, write the uprobe definition directly into tracefs using the hardlink path

# Where logs are saved

The helper writes into:

- `dev/pc/logs/host-trace-handle-select-<timestamp>.txt`
- `dev/pc/logs/host-trace-handle-select-<timestamp>.data`
- `dev/pc/logs/host-trace-handle-select-<timestamp>.perf-record.log`
- `dev/pc/logs/host-trace-handle-select-<timestamp>.setup.log`

# Setup-only validation

The helper supports a setup-only mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh --setup-only
```

In setup-only mode it:

1. creates the temporary hardlink
2. creates the probe set
3. verifies the probes appear in `perf probe -l`
4. trims leading whitespace before parsing each event name
5. exits without starting `perf record`
6. removes the temporary probes on exit
7. removes the temporary hardlink on exit
8. prints `Setup-only validation succeeded: ...` instead of the normal install banner

The corrected probe strategy is:

1. `perf probe -x "$NWN_BIN" --definition` for each stable event name/spec pair
2. create a hardlink such as `/tmp/nwmain-linux-hardlink`
3. `sudo perf probe -x "$TRACE_NWN_BIN" --add` for each event name/offset pair
4. if that fails with `Invalid argument`, fallback to direct tracefs write using the hardlink path
5. confirm `sudo perf probe -l` shows the created `probe_nwmain:*` events

# How cleanup works

Cleanup is automatic:

- a trap removes the temporary perf probe on exit
- the background perf record process is stopped when tracing ends
- stale probes are removed before the new probe is added
- the temporary hardlink is removed on exit
- if `--kill-on-exit` is used, it also attempts to stop the launched child process tree. The default is to leave the game running.

If the script exits early, it still attempts to remove the probe in its exit trap.

# Operating modes

Default mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh
```

This launches the PC harness, discovers the real `nwmain-linux` PID, and records against that PID.

Setup-only mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh --setup-only
```

This validates probe creation only. It does not launch NWN and does not start `perf record`.

No-launch attach mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh --no-launch
```

This skips the helper-launched harness and attaches to an already-running `nwmain-linux` process by inode. This is the mode to use for Steam/manual control later.

Optional cleanup mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh --kill-on-exit
```

This keeps the helper-launched mode but opts into terminating the launched game process tree during cleanup.

# Notes

- This helper uses `perf` only.
- It does not use `bpftrace`, `gdb`, or `rr`.
- It does not modify NWN, the wrapper, the port, or the bootstrap scripts.
- The setup log records every attempted probe form, its exit code, and its stdout/stderr.
