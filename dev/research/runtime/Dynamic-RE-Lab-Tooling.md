# Goal

Design the minimal dynamic reverse-engineering lab for NWN:EE on Linux/x86_64 and R36S/ARM64 before touching the live process.

This note is research-only. It does not run tracing, attach debuggers, or modify runtime behavior.

# Current local tool availability

## Available in `PATH`

- `gdb` at `/usr/bin/gdb`
- `ltrace` at `/usr/bin/ltrace`
- `strace` at `/usr/bin/strace`
- `nm`
- `readelf`

## Not found in `PATH`

- `perf`
- `bpftrace`
- `rr`
- `uftrace`
- `frida`
- `radare2`
- `rizin`
- `eu-stack`
- `systemtap`
- `bpftool`

## Implication

The current machine can do static analysis plus `gdb`/`strace`/`ltrace`, but it does not yet have the best passive tracing tools (`perf`, `bpftrace`) installed.

# Tool evaluation matrix

| Tool | Purpose | PC suitability | R36S suitability | Root required | Kernel support | Install package | Risk | Verdict |
|---|---|---|---|---|---|---|---|---|
| `perf` | Passive function probes, call counts, some argument capture via uprobes | High | Medium | Sometimes | Yes, perf events / uprobes | `linux-perf` or `linux-tools-common linux-tools-generic linux-tools-$(uname -r)` | Low | Best first install for passive observation on PC; useful on ARM64 if the kernel supports it. |
| `bpftrace` | Passive uprobes, argument printing, event correlation | High | Low to Medium | Often yes | Yes, eBPF / uprobes / BTF helps | `bpftrace bpftool` | Low to Moderate | Very strong for PC lab; often too heavy or unsupported on R36S. |
| `gdb` | Arguments, object pointers, hardware watchpoints, state inspection | High | Medium | No for attach; maybe for ptrace permissions | No special kernel features beyond ptrace | `gdb` | Moderate | Necessary fallback for field-level state inspection; avoid software breakpoints when possible. |
| `rr` | Repeatable record/replay debugging | High on x86_64 | Low to None | No, but ptrace/record permissions matter | Needs kernel/CPU support | `rr` | Moderate | Excellent for x86_64 postmortem-style debugging; not a realistic R36S tool. |
| `uftrace` | User-space function tracing, call graphs | Medium to High | Low to Medium | Usually no | Some kernel/perf support helps | `uftrace` | Low to Moderate | Potentially useful if `perf`/`bpftrace` are unavailable, but less standard than `perf`. |
| `ltrace` | libc / dynamic library call tracing | Medium | Low to Medium | Usually no | Minimal | `ltrace` | Moderate | Useful for file-system and library-call visibility, but not for deep C++ state. |
| `strace` | Syscall tracing | High | High | Usually no | Minimal | `strace` | Low | Good for file behavior and process-level sanity checks; not enough for internal state. |
| Frida | Dynamic instrumentation | High on PC | Low on R36S | Often no | Needs runtime injection support | `frida-tools` / distro packages vary | Moderate to High | Powerful but heavier and more invasive than needed for this project. |
| `radare2` / `rizin` | Static / offline reverse engineering | High | High | No | No | `radare2` or `rizin` | Low | Very useful for analysis, not tracing. Keep installed for offline work. |
| `objdump` / `nm` / `readelf` | Static symbol and disassembly inspection | High | High | No | No | `binutils` | Low | Essential baseline tools; already useful and low risk. |
| `eu-stack` / elfutils | Postmortem stack traces from core dumps | Medium | Medium | No | No | `elfutils` | Low | Good fallback for crash/core analysis, not live tracing. |
| SystemTap | Kernel/user probes | Medium on PC | Low on R36S | Often yes | Heavy kernel/module requirements | `systemtap systemtap-runtime` | High | Too heavy for the first pass; only if everything else fails. |
| eBPF tooling generally | Uprobes, syscall and event tracing | High on PC | Low to Medium | Often yes | Strong kernel support required | `bpftrace bpftool` plus kernel headers | Low to Moderate | Best class of passive tooling, but only if kernel support and packages are available. |

# Recommended stack

## PC lab

Recommended order:

1. `perf`
2. `bpftrace` + `bpftool`
3. `gdb`
4. `strace`
5. `ltrace`
6. `rr`
7. `elfutils`
8. `radare2` or `rizin`

Why:

- `perf` and `bpftrace` give the safest passive observation for function entry/exit and selected arguments.
- `gdb` is the best fallback for object fields and hardware watchpoints.
- `strace` and `ltrace` are useful for quick sanity checks and file-system behavior.
- `rr` is great on x86_64 for repeatable replay, but it is not the first tool to install.

## R36S lab

Recommended order:

1. `gdb` or `gdbserver`
2. `strace`
3. `ltrace`
4. `elfutils`
5. static tools only (`nm`, `readelf`, `objdump`)

Why:

- R36S is the place where heavy tracing is most likely to be painful.
- `gdb` watchpoints are still useful if access is limited to a single field at a time.
- `strace` is the safest low-cost runtime visibility tool.
- `ltrace` can help with library calls, but internal C++ state still needs `gdb` or passive uprobes.

## Fallback tools

- `strace`
- `ltrace`
- `gdb` hardware watchpoints
- `elfutils`
- static analysis tools (`nm`, `readelf`, `objdump`)

These are the fallback tools if `perf` and `bpftrace` are unavailable.

## Avoid for now

- SystemTap
- Frida
- any injected helper / patching approach
- software breakpoints in the hot UI path

Reason:

- they are heavier, more intrusive, or more complex than necessary for the current selection-state question.

# Install checklist

Do not run these commands yet.

## PC x86_64

```bash
sudo apt update
sudo apt install gdb strace ltrace elfutils radare2 rizin rr uftrace systemtap systemtap-runtime bpftool bpftrace
sudo apt install linux-perf
```

If `linux-perf` is not the correct package name on the local distro, use the kernel-matched Linux tools package set instead:

```bash
sudo apt install linux-tools-common linux-tools-generic linux-tools-$(uname -r)
```

## R36S / ARM64

Do not assume a package manager is available or usable on-device.

If package installation is possible on the device, prefer only the lightest tools:

```bash
sudo apt install gdbserver strace ltrace
```

But in practice, R36S is better treated as a target for:

- one-off `gdb` / `gdbserver` sessions
- `strace` only when necessary
- static binary inspection from the PC

# First experiment after installation

Exactly one experiment:

Observe that `CPanelLoadSave::HandleSelectSaveGame(int)` runs before `CPanelLoadGame::SendLoadGameRequest()` and capture the selected index at the selection callback entry.

Why this is the best first runtime observation:

- it confirms the selection-to-request ordering
- it captures the one value that must survive into the load path
- it does not require changing the game or guessing internal fields

# Final recommendation

What software should be installed next, and why?

Install `perf`-class tooling first on the PC lab, then `bpftrace`/`bpftool`, then keep `gdb`, `strace`, and `ltrace` ready as fallbacks.

Why:

- `perf` and `bpftrace` are the lowest-risk ways to observe native function entry/exit and arguments without modifying the game.
- `gdb` is the safest field-level fallback when a single internal state variable must be watched.
- `strace` and `ltrace` provide simple sanity checks for filesystem and library behavior.
- R36S should remain a minimal target, not the primary tracing host.
