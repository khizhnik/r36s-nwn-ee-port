# Goal

Determine why `perf probe --add` failed for `CPanelLoadSave::HandleSelectSaveGame(int)` even though `nm` and `perf probe --funcs` could resolve it, and identify the correct runtime probe-creation strategy for this binary.

This note is research-only. It does not run tracing or modify runtime behavior.

# Observed failures

The helper / probe attempts produced these failures before the final strategy was understood:

- `Semantic error: There is non-digit char in line number`
- `Internal error: "CPanelLoadSave::HandleSelectSaveGame" is an invalid event name`
- `Failed to write event: Invalid argument`

Those failures came from trying probe forms that perf or tracefs did not accept for this binary.

Later manual tracefs testing added these findings:

- the original NWN binary path contains a space
- direct tracefs writes against the original path fail
- escaping the space as `\040` also fails
- a symlink path also fails
- a real copy without spaces works, but changes the inode and is not ideal for the live game
- a hardlink without spaces works and preserves the inode

# Symbol evidence

## Resolved symbol table

The x86 binary resolves the function in `nm`:

- `CPanelLoadSave::HandleSelectSaveGame(int)` at `0x6fd500`

`perf probe --funcs` also lists the function name successfully, which proves symbol discovery works.

## Working `perf probe` evidence

The successful resolution command was:

```bash
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux --definition 'nwn_handle_select=CPanelLoadSave\:\:HandleSelectSaveGame'
```

It produced the concrete tracefs-ready definition:

```text
p:probe_nwmain/nwn_handle_select ~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux:0x6fd500
```

That is the decisive evidence: perf accepts the escaped demangled symbol for resolution, and `--definition` can be used to verify the resolved offset. The actual runtime probe path is the hardlink path without spaces.

# ELF / PIE analysis

## Binary type

The x86 NWN binary is:

- `ELF 64-bit LSB pie executable, x86-64`
- `Type: DYN (Position-Independent Executable file)`

## What that means

This is a PIE executable, but that does **not** prevent perf from resolving the symbol by name for uprobe creation.

The working runtime add form is hardlink-based, not original-path-based.

# perf probe behavior analysis

## Why `--funcs` worked but earlier `--add` attempts failed

`perf probe --funcs` only enumerates candidate symbols.

`perf probe --add` must turn the candidate into a tracefs uprobe definition.

The earlier failures show that the helper was handing perf probe forms it did not accept in this case.

In contrast:

- `perf probe --definition` with an explicit event name and escaped demangled symbol produced a valid resolved definition
- the runtime add path must avoid the original path with spaces
- the runtime add path uses a hardlink without spaces

## The real root cause

The root cause is **tracefs path handling** on the original add attempts, not missing symbol discovery.

More specifically:

1. The symbol is discoverable.
2. The raw demangled form by itself is not the robust add form for this binary.
3. The original path with spaces is not usable for the real tracefs add.
4. A hardlink path without spaces is the preferred real add path.

## Not the root cause

The evidence does **not** point to:

- missing `nm` symbols
- missing `perf` support for the binary
- a PIE blocker
- a mangled-name-only requirement
- stale probe state as the primary issue

Stale probe cleanup is still useful in the helper, but it is not the root cause of the runtime add failures.

# tracefs uprobe syntax analysis

The resolved tracefs-visible event is:

```text
probe_nwmain:nwn_handle_select
```

That implies the correct strategy is:

1. create the uprobe with an explicit event name
2. resolve the function to a concrete offset
3. add the probe using a hardlink path without spaces
4. record using the discovered event name

# Correct strategy

## Recommended probe creation path

Use the explicit event name plus the hardlink path and resolved offset:

```bash
perf probe -x ~/.steam/debian-installation/steamapps/common/Neverwinter\ Nights/bin/linux-x86/nwmain-linux --definition 'nwn_handle_select=CPanelLoadSave\:\:HandleSelectSaveGame'
sudo perf probe -x /tmp/nwmain-linux-hardlink --add "nwn_handle_select=0x6fd500"
```

If `perf probe -x /tmp/nwmain-linux-hardlink --add ...` still returns `Invalid argument`, the fallback is a direct tracefs write using the same hardlink path and offset.

## Why this is the correct strategy

- It avoids the ambiguous original path with spaces.
- It keeps the event name stable and simple.
- It works with the binary as shipped, as proven by the successful hardlink-based tracefs experiment.

# Recommended host command

The next command the host user should run manually is the helper in setup-only mode:

```bash
sudo bash dev/pc/scripts/host-trace-handle-select.sh --setup-only
```

This validates the hardlink-based strategy without starting the full record session.

# Helper script changes

The helper script was changed for one reason:

- to create a temporary hardlink without spaces, then add the probe against that hardlink path

That is necessary because the original binary path with spaces fails for the real tracefs add, while the hardlink path works.
