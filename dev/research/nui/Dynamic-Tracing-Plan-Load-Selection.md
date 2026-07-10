# Goal

Prepare a minimal, safe, repeatable tracing plan for observing native NWN:EE Load Game selection state on Linux without modifying game behavior.

This note is research-only. It does not run tracing.

# Safety rules

- Do not patch or inject into the game binary.
- Prefer passive tracing first.
- Do not use software breakpoints unless explicitly necessary.
- Use one watchpoint at a time if `gdb` is needed.
- Detach cleanly after each observation.
- Keep observations focused on the selection lifecycle, not full gameplay.

# Required tools

## Availability on this machine

| Tool | Status | Path |
|---|---|---|
| `perf` | Not found in `PATH` | unavailable |
| `bpftrace` | Not found in `PATH` | unavailable |
| `gdb` | Available | `/usr/bin/gdb` |
| `nm` | Available | `/usr/bin/nm` |
| `readelf` | Available | `/usr/bin/readelf` |

## Notes

- `perf` and `bpftrace` are the preferred passive tracing tools, but they are not installed in the current PATH here.
- `gdb` remains available as the fallback for watchpoints.

# Symbols and addresses

The following target symbols were identified from `nwmain-linux` on both x86 and ARM64.

| Function | x86 address | ARM64 address | Notes |
|---|---:|---:|---|
| `CPanelLoadSave::HandleSelectSaveGame(int)` | `0x6fd500` | `0x6fbdc0` | Main selection entry point. |
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6fa1d0` | `0x6f8e78` | Load-request handoff. |
| `CExoResMan::AddResourceDirectory(CExoString const&, unsigned int, int, bool (*)(CExoKeyTable*, CResRef const&, unsigned short))` | `0x53bac0` | `0x5616b0` | Resource manager registration during selection. |
| `CNWPortrait::ReplacePortraitTexture(CAurObject*, CResRef const&)` | `0x81f240` | `0x7ff400` | Portrait refresh path. |
| `CSaveGameList::GetSaveGameName(int)` | `0x6f7cc0` | `0x6f69f0` | Selected-save name lookup. |
| `CSaveGameList::GetSaveGameFileInfo(int)` | `0x6f7f10` | `0x6f6c38` | Selected-save metadata lookup. |

# Phase 1: passive tracing

`perf` and `bpftrace` are not available in `PATH` on this machine, but the following commands are the intended passive-tracing templates on a system where they are installed.

## `perf probe`

### Observe entry/exit for the selection callback

```bash
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux \
  'CPanelLoadSave::HandleSelectSaveGame selected=%di'
perf record -e probe_nwmain_linux:CPanelLoadSave__HandleSelectSaveGame -- \
  env DISPLAY=:0 ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux
perf script
```

### Observe the request handoff

```bash
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux \
  'CPanelLoadGame::SendLoadGameRequest'
perf record -e probe_nwmain_linux:CPanelLoadGame__SendLoadGameRequest -- \
  env DISPLAY=:0 ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux
perf script
```

### Observe resource and portrait setup

```bash
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux \
  'CExoResMan::AddResourceDirectory'
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux \
  'CNWPortrait::ReplacePortraitTexture'
```

## `bpftrace`

### Selection callback and request handoff

```bash
bpftrace -e '
uprobe:~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux:CPanelLoadSave::HandleSelectSaveGame
{
  printf("HandleSelectSaveGame this=%p selected_index=%d\n", arg0, arg1);
}
uprobe:~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux:CPanelLoadGame::SendLoadGameRequest
{
  printf("SendLoadGameRequest this=%p\n", arg0);
}
'
```

### Resource and portrait helpers

```bash
bpftrace -e '
uprobe:~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux:CExoResMan::AddResourceDirectory
{
  printf("AddResourceDirectory this=%p path_ptr=%p\n", arg0, arg1);
}
uprobe:~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux:CNWPortrait::ReplacePortraitTexture
{
  printf("ReplacePortraitTexture this=%p obj=%p resref=%p\n", arg0, arg1, arg2);
}
'
```

## Command availability note

Because `perf` and `bpftrace` are not installed here, these commands are templates for a fuller Linux tracing environment. They are still included because they are the safest passive-observation options.

# Phase 2: observing arguments

## Selected index to `HandleSelectSaveGame(int)`

The index is the integer argument to the function itself.

Best passive observation:

- trace the function entry
- print `arg1` in `bpftrace`
- or capture the integer argument via a probe in `perf`

## `this` pointer for panel methods

For member functions:

- `arg0` is the implicit `this` pointer in System V x86-64 / ARM64 calling conventions used by these tools at the user-space probe level.

Use it to correlate:

- `CPanelLoadSave`
- `CPanelLoadGame`
- later selection-state reads

## `CExoString` arguments

Feasible only if:

- the function signature is known
- the relevant `CExoString` is passed by reference or pointer in a stable ABI position

In practice, for passive tracing:

- first capture addresses
- then inspect memory only if needed

## Object addresses passed to `AddResourceDirectory` and `ReplacePortraitTexture`

At the probe level:

- print `arg0` for `this`
- print `arg1`/`arg2` as raw pointers

Do **not** dereference them in the first pass unless you have a strong reason.

# Phase 3: gdb watchpoint fallback

If passive tracing is unavailable or insufficient, use `gdb` only as a fallback.

## Safe attachment pattern

1. Start the game normally.
2. Attach `gdb` to the running `nwmain-linux`.
3. Identify the panel object address from a passive trace or a single breakpoint-free observation.
4. Set **one hardware watchpoint** on a single field.
5. Continue until the watched field changes.
6. Record the change.
7. Remove the watchpoint and detach.

## Rules

- Prefer hardware watchpoints only.
- Avoid software breakpoints in hot UI code.
- Watch one field at a time.
- Do not keep `gdb` attached longer than needed.
- Detach cleanly when done.

# Risks

## `perf`

- Not available in the current PATH here.
- On a system with support, it is low risk because it is passive.
- Requires symbol/probe availability and may need root or perf_event permissions.

## `bpftrace`

- Not available in the current PATH here.
- If available, it is also low risk because it is passive.
- Can be blocked by kernel security settings or missing uprobes support.

## `gdb`

- Can stop the process if used with breakpoints.
- Hardware watchpoints are safer but still intrusive because they pause execution on change.
- Best used only after the passive path has narrowed the field of interest.

## Hardware watchpoints

- Limited in number.
- Best for a single integer / pointer field.
- Can be noisy if the watched field is mutated frequently.

## Running under X11/Steam

- The game may be sensitive to timing.
- Interactive tracing can perturb the UI if the game is already fragile.
- Keep the observation window short.

# Recommended first actual experiment

Observe one event chain:

1. `CPanelLoadSave::HandleSelectSaveGame(int)`
2. `CPanelLoadGame::SendLoadGameRequest()`

and capture the selected index at `HandleSelectSaveGame(int)` entry.

Why this is the smallest useful experiment:

- it confirms the selection callback fires before the load request
- it captures the one state item that must survive into later load logic
- it does not require modifying the game or guessing internal state layout