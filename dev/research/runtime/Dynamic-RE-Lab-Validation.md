# Goal

Validate that the dynamic reverse-engineering lab is actually ready before the first runtime experiment against NWN:EE.

This is a laboratory validation note only. It does not trace the game, attach debuggers, or modify runtime behavior.

# Installed tools

| Tool | Version / status |
|---|---|
| `perf` | `perf version 6.1.174` |
| `bpftrace` | `bpftrace v0.17.0` |
| `bpftool` | `bpftool v7.1.0` (`libbpf v1.1`) |
| `gdb` | `GNU gdb (Debian 13.1-3) 13.1` |
| `rr` | `rr version 5.6.0` |
| `uftrace` | `uftrace v0.13` |
| `strace` | `strace -- version 6.1` |
| `ltrace` | `ltrace version 0.7.3` |

# Kernel capabilities

| Item | Result |
|---|---|
| Kernel | `Linux 13DEV 6.1.0-48-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.172-1 (2026-05-15) x86_64 GNU/Linux` |
| Kernel release | `6.1.0-48-amd64` |
| Distro | `LMDE 6 (faye)` |
| `perf_event_paranoid` | `3` |
| `kptr_restrict` | `0` |
| `ptrace_scope` | `0` |
| `tracefs` mount | present |
| `tracefs` on `/sys/kernel/tracing` | `ro` |
| `tracefs` on `/sys/kernel/debug/tracing` | `rw` |
| `debugfs` on `/sys/kernel/debug` | `ro` |

## Interpretation

- `perf_event_paranoid=3` is restrictive and makes perf-style observation difficult without elevated privileges.
- `bpftrace` reported that it requires root.
- The system has kernel support for BPF events / uprobes in general, but unprivileged eBPF is restricted.

# Permission status

| Check | Result |
|---|---|
| `bpftool feature probe unprivileged` | reports `bpf() syscall restricted to privileged users` |
| `bpftrace -l ...` | fails with `bpftrace currently only supports running as the root user` |
| `perf probe -n ... --add ...` | fails with `No permission to write tracefs` |

## Interpretation

The lab is not fully usable from the current unprivileged session.

The main blockers are:

- root / elevated permission requirement for `bpftrace`
- tracefs write permission for `perf probe`
- restrictive perf event policy (`perf_event_paranoid=3`)

# Symbol validation

## Symbol discovery method

The relevant functions were validated with:

- `nm -C`
- `nm` for mangled names
- `perf probe --funcs`

## Target functions resolved successfully

### x86_64

| Function | Address | Validation |
|---|---:|---|
| `CPanelLoadSave::HandleSelectSaveGame(int)` | `0x6fd500` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6fa1d0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CExoResMan::AddResourceDirectory(...)` | `0x53bac0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CNWPortrait::ReplacePortraitTexture(...)` | `0x81f240` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CSaveGameList::GetSaveGameName(int)` | `0x6f7cc0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CSaveGameList::GetSaveGameFileInfo(int)` | `0x6f7f10` | Resolved by `nm`, listed by `perf probe --funcs` |

### ARM64

| Function | Address | Validation |
|---|---:|---|
| `CPanelLoadSave::HandleSelectSaveGame(int)` | `0x6fbdc0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6f8e78` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CExoResMan::AddResourceDirectory(...)` | `0x5616b0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CNWPortrait::ReplacePortraitTexture(...)` | `0x7ff400` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CSaveGameList::GetSaveGameName(int)` | `0x6f69f0` | Resolved by `nm`, listed by `perf probe --funcs` |
| `CSaveGameList::GetSaveGameFileInfo(int)` | `0x6f6c38` | Resolved by `nm`, listed by `perf probe --funcs` |

## What did not fully validate

`perf probe --add` could identify the symbols only up to the point of writing tracefs; the actual probe installation failed because the current session cannot write to tracefs.

# Passive tracing validation

## `perf`

### Result

Partially usable.

### Evidence

- `perf probe --funcs` can enumerate the relevant symbols in both x86_64 and ARM64 binaries.
- `perf probe -n --add ...` fails in this session with:
  - `No permission to write tracefs`

### Conclusion

`perf` is symbol-aware and probe-capable in principle, but not yet usable from the current unprivileged environment without elevated permissions or tracefs access changes.

## `bpftrace`

### Result

Not usable from the current session.

### Evidence

- `bpftrace -l ...` fails with:
  - `bpftrace currently only supports running as the root user`
- `bpftool feature probe unprivileged` reports the BPF syscall is restricted to privileged users.

### Conclusion

`bpftrace` is installed, but it is effectively root-only here.

## Uprobes

### Result

Kernel support exists, but user-space probe creation is blocked by permissions.

### Evidence

- `CONFIG_UPROBE_EVENTS=y`
- `CONFIG_BPF_EVENTS=y`
- `perf probe` cannot create the probe without tracefs write access.

# First runtime experiment

Not run.

## Reason

The lab is not fully ready from the current unprivileged session:

- `perf` cannot write tracefs
- `bpftrace` requires root
- the first passive experiment would not be reliable without elevated access or a tracefs setup that the current session can write to

## Intended first experiment once permissions are available

Observe `CPanelLoadSave::HandleSelectSaveGame(int)` and `CPanelLoadGame::SendLoadGameRequest()` in a passive way, confirming that the selection callback runs before the load request and capturing the selected index at callback entry.

# Final assessment

**PARTIALLY READY**

## Why

The lab has the right tools installed and the target symbols are resolvable on both x86_64 and ARM64.

However, the current session cannot yet create uprobes:

- `perf probe` is blocked by tracefs write permissions
- `bpftrace` requires root
- `perf_event_paranoid=3` is restrictive

So the lab is ready in terms of tooling and symbol knowledge, but not ready in the current permission context for the first passive runtime experiment.

# Recommended next experiment

Grant the lab an execution context that can write tracefs and run a single passive uprobe observation on:

- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadGame::SendLoadGameRequest()`

Why this one:

- it is the smallest experiment that validates the selection-to-request ordering
- it does not require memory inspection or breakpoints
- it directly tells us whether the passive tracing path is ready for the next stage
