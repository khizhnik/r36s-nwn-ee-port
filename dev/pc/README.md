# PC NUI Bootstrap Harness

This directory contains PC-side development artifacts for NUI and bootstrap testing.

It is separate from the validated `port/` tree and must not modify the runnable port layout.

## Layout

- `scripts/` - helper scripts for PC-side launch and diagnostics
- `userdir/` - isolated NWN user directory for test runs
- `logs/` - stdout/stderr and NWN runtime logs from PC testing

## Runtime target

The harness uses the Steam Neverwinter Nights installation at:

`$HOME/.steam/debian-installation/steamapps/common/Neverwinter Nights`

You can override it by exporting `STEAM_NWN_DIR`.

The harness is intended for desktop bootstrap testing only. It does not launch the R36S port.
