# Current state

This guide documents the minimum reversible configuration needed for passive user-space tracing on this workstation.

## Observed current values

- `kernel.perf_event_paranoid = 3`
- `kernel.kptr_restrict = 0`
- `kernel.yama.ptrace_scope = 0`
- `tracefs` exists at:
  - `/sys/kernel/tracing` mounted `ro`
  - `/sys/kernel/debug/tracing` mounted `rw`
- `debugfs` exists at:
  - `/sys/kernel/debug` mounted `ro`

## Tool status

- `perf` installed
- `bpftrace` installed
- `bpftool` installed
- `gdb` installed
- `strace` installed
- `ltrace` installed

## Evidence from Linux documentation

### `perf_event_paranoid`

From `man 2 perf_event_open`:

- `2` allows only user-space measurements
- `1` allows both kernel and user measurements
- `0` allows access to CPU-specific data but not raw tracepoint samples
- `-1` means no restrictions

The same manpage also notes that some operations require `CAP_PERFMON`, `CAP_SYS_ADMIN`, or a more permissive `perf_event_paranoid` setting.

### `perf probe`

From `man perf-probe`:

- `perf probe` depends on `tracefs` and `kallsyms`
- `--add`, `--del`, and `--list` require root or a privileged user
- the system administrator can remount tracefs with `mode=755` to allow unprivileged `perf probe --list`
- `kptr_restrict = 2` blocks useful kallsyms access for kernel probing

### `bpftrace`

From `man bpftrace` and runtime checks:

- `bpftrace` supports uprobes on x86_64 and arm64
- the installed binary reports that it currently only supports running as root in this environment
- `bpftool feature probe unprivileged` reports BPF syscall access is restricted to privileged users

# Required changes

## What is actually required for our planned passive tracing

### Option A: trace as root, keep kernel knobs unchanged

This is the smallest reversible option.

- Run `perf probe` / `perf record` as root or with sudo
- Run `bpftrace` as root
- Do **not** change `perf_event_paranoid`
- Do **not** change `kptr_restrict`
- Do **not** change `ptrace_scope`

This works because the blockers seen in validation were permission-related, not capability-related.

### Option B: allow unprivileged user-space perf measurement

If we want non-root `perf` for user-space-only measurement, the minimum documented `perf_event_paranoid` value is:

- `2` for user-space-only measurements

That is the smallest documented setting that still permits user-space measurements without opening kernel measurements.

For our project:

- `2` is the minimum perf-related sysctl value worth considering
- `1`, `0`, and `-1` are broader than necessary for passive user-space tracing

### Option C: unprivileged `perf probe --list` only

If the only goal is to allow listing probes without root, the `perf-probe` manpage says tracefs can be remounted with `mode=755`.

However:

- this only helps `--list`
- `--add` and `--del` still require root or a privileged user

So it is not sufficient by itself for actual tracing setup.

# Temporary commands

Do not run these automatically; they are listed for reference only.

## Temporary perf user-space measurement setting

```bash
sudo sysctl -w kernel.perf_event_paranoid=2
```

## Temporary tracefs readability for listing probes only

```bash
sudo mount -o remount,mode=755 /sys/kernel/tracing
```

## Temporary tracing session as root

```bash
sudo perf probe --add 'CPanelLoadSave::HandleSelectSaveGame'
sudo bpftrace -e 'uprobe:/path/to/nwmain-linux:... { ... }'
```

## Revert the temporary perf setting

```bash
sudo sysctl -w kernel.perf_event_paranoid=3
```

# Permanent commands

If permanent changes are ever justified, use explicit configuration files rather than ad-hoc runtime changes.

## Persistent perf setting

Create a file under `/etc/sysctl.d/`, for example:

```bash
sudoedit /etc/sysctl.d/99-nwn-tracing.conf
```

Suggested contents if unprivileged user-space perf is desired:

```text
kernel.perf_event_paranoid = 2
```

Then apply with:

```bash
sudo sysctl --system
```

## Persistent tracefs mount mode

If the system administrator wants unprivileged `perf probe --list`, the tracefs mount can be managed via boot-time or systemd mount configuration.

This is optional and not required for root-run tracing.

# Security implications

## `kernel.perf_event_paranoid`

- `3`: most restrictive of the documented values seen here; blocks the planned unprivileged tracing use case
- `2`: allows user-space measurements only; smallest documented value suitable for user-space-only perf work
- `1`: enables kernel + user measurements; broader than needed for this project
- `0`: allows CPU-specific data and is broader still
- `-1`: no restrictions; not appropriate for this project

## `tracefs` remount mode

- `mode=755` helps probe listing for unprivileged users
- it does not make `perf probe --add` or `--del` unprivileged

## Root-run tracing

- Minimal long-term security impact if done only in short-lived sessions
- Does not require weakening the kernel permanently
- Best fit for our current passive tracing needs

## `ptrace_scope` and `kptr_restrict`

- Current values do not need to change for the recommended root-run passive tracing plan
- Raising `kptr_restrict` would make kernel symbol work harder, but that is not required for user-space uprobes on `nwmain-linux`

# Recommended configuration for this project

## Recommended baseline

1. Keep the workstation at the current kernel defaults.
2. Use `sudo` for probe creation / attachment when needed.
3. Run `bpftrace` as root if it is used at all.
4. Only lower `kernel.perf_event_paranoid` to `2` if a non-root user-space perf workflow is specifically required.

## Why this is the smallest reversible setup

- It avoids permanently weakening the system.
- It preserves the current restrictive `perf_event_paranoid=3` setting unless non-root perf is actually required.
- It lets us validate the passive tracing lab with minimal system change.

## Practical recommendation

For this project:

- use root-run `perf` / `bpftrace` sessions for the first experiments
- do not change `perf_event_paranoid` unless a non-root workflow becomes necessary
- do not remount tracefs permanently

# Final conclusion

The minimum reversible configuration is **not** a kernel-wide weakening for the first passive tracing pass.

The safest path is:

- keep the system as-is
- run tracing tools with `sudo` / root

If a non-root perf workflow is later required, the minimum documented sysctl change is:

- `kernel.perf_event_paranoid = 2`

That is the smallest value suitable for user-space-only measurements and is strictly less permissive than `1`, `0`, or `-1`.
