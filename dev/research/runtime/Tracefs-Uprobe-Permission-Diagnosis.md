# Goal

Record the confirmed manual findings for the NWN user-space uprobe setup path.

# Confirmed findings

## Original binary path

- original path:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- it contains a space in `Neverwinter Nights`
- direct tracefs writes against the original path fail with `Invalid argument`

## Escaped-space attempt

- escaping the space as `\040` also fails

## Symlink attempt

- a symlink to the original binary fails

## Copy attempt

- a real copy without spaces works
- but a copy creates a different inode, so it is not the preferred runtime target

## Hardlink attempt

- a hardlink without spaces works
- the hardlink preserves the inode
- the hardlink path used during manual testing was:
  - `/tmp/nwmain-linux-hardlink`

## Cleanup

- deleting the probe with:
  - `sudo perf probe --del 'probe_nwmain:nwn_handle_select'`
  works and reports:
  - `Removed event: probe_nwmain:nwn_handle_select`

# Recommended runtime strategy

1. create a hardlink without spaces
2. resolve the function offset with `perf probe --definition`
3. add the probe against the hardlink path
4. record using the event name discovered by `perf probe -l`

# Notes

- This note is about uprobe path handling only.
- It does not change the NWN runtime.
- It is intended as a stable reference for future trace helper maintenance.
