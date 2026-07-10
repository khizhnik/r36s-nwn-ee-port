# Goal

Perform the first passive runtime observation of `CPanelLoadSave::HandleSelectSaveGame(int)` without modifying NWN, the wrapper, or the port.

This note records the attempt and the blocker. It does not implement tracing.

# Tool used

- Intended tool: `perf` uprobe
- Fallback not used: `bpftrace`

## Why `perf`

`perf` is the least invasive tool that can create a user-space uprobe in this environment without modifying the game.

# Commands

## Probe creation attempt

Timestamp:

- `2026-07-02T15:34:47+03:00`
- `2026-07-02T12:34:47Z`

Command attempted:

```bash
sudo perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux --add 'CPanelLoadSave::HandleSelectSaveGame'
```

## Privileged tool revalidation attempt

Commands attempted:

```bash
sudo perf --version
sudo bpftrace --version
sudo bpftool version
```

## Probe listing attempt

Command attempted:

```bash
sudo perf probe -l | rg 'HandleSelectSaveGame'
```

# Whether the probe attached

**No.**

The probe could not be created because `sudo` was blocked by the container security context before privilege escalation could occur:

```text
sudo: /etc/sudo.conf is owned by uid 65534, should be 0
sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
sudo: If sudo is running in a container, you may need to adjust the container configuration to disable the flag.
```

# Whether `HandleSelectSaveGame()` fired

**Not observed.**

The game was not traced successfully, so there was no runtime event to record.

# Permission issues

Observed failure:

```text
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
```

This is the blocking issue for the current session.

# Unexpected observations

- None from the game itself.
- The blocker was entirely at the privilege boundary, before any probe could be installed.
- The updated sudo permissions advertised outside this session were not usable here because the container forbids privilege escalation with `no_new_privs`.

# Final result

**FAILED**

Reason:

- The least invasive tool (`perf`) was the correct choice.
- The probe command could not be executed because `sudo` could not elevate in this container session.
- Since the probe never attached, the function could not be observed.

# Notes for the next attempt

To complete this experiment, the tracing session needs one of the following:

- a tracing environment without the container `no_new_privs` restriction
- a root shell / privileged tracing session that is not blocked by `sudo` policy
- a host-side session where `sudo perf` can actually execute

Without one of those, the first passive runtime observation cannot be completed from this environment.
