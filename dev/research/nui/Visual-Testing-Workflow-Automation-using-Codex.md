## Visual Testing Workflow Automation using Codex

Codex may not always have access to the visible desktop session.

Known working visible-session approach on PC:

```bash
DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" dev/pc/scripts/run-nui-bootstrap.sh test 03_r36s_bootstrap_nui_window
```

Codex successfully used X11 automation with Python Xlib/XTEST to click the visible NWN window.

Useful checks:

```bash
xprop -id <window_id> WM_NAME WM_CLASS _NET_WM_PID
```

Expected class/name:

```text
WM_CLASS = "nwmain-linux", "nwmain-linux"
WM_NAME = "Neverwinter Nights: Enhanced Edition ..."
```

If visual tools cannot access `:0`, do not continue blind UI layout edits. Use manual screenshots.

**Basically I think this trick will work also for Codex but didn't test it with it.**