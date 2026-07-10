# Goal

Determine what data is carried through the native load-request path so the custom NUI launcher can eventually trigger the same flow without reimplementing the server-side load logic.

The current goal is narrower than the earlier load-flow work:

- do not count function hits
- do not revalidate the chain
- do not patch NWN
- do not implement loading yet

Instead, capture the arguments and payload data passed through:

- `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

This is the narrowest useful observation point because it is the first client-side handoff after the panel layer and its signature is explicit.

# Confirmed load-request chain

Already confirmed by perf tracing and static disassembly:

1. `CPanelLoadGame::HandleOkButton`
2. `CPanelLoadGame::SendLoadGameRequest`
3. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
4. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
5. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

Selection/preview lifecycle is separate and already confirmed:

- `CPanelLoadSave::HandleSelectSaveGame`
- `CExoResMan::AddResourceDirectory`
- `CNWPortrait::ReplacePortraitTexture`

That lifecycle does not explain the actual load payload.

# Target functions

## Primary target

`CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

Known address on x86_64 build:

- `0x637960`

Role:

- client-side facade for the load request
- forwards to `CClientExoAppInternal::SendLoadGameRequest`

This is the best first place to observe the real payload that the panel passes into the load path.

## Supporting context

`CPanelLoadGame::SendLoadGameRequest()`

- known address: `0x6fa1d0`
- panel-level request builder
- fetches selected save metadata and password-related state

`CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`

- known address: `0x8027b0`
- message-layer handoff toward the server-side load path

`CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

- known address: `0x9fe780`
- server-side confirmation that the request reaches actual load execution

# Confirmed ABI

For the x86_64 SysV ABI, the public method entry mapping for

`CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

is:

- `rdi` = `this`
- `rsi` = `unsigned int`
- `rdx` = `CExoString&` #1
- `rcx` = `CExoString&` #2
- `r8d` = `int`

This is consistent with the disassembly of the wrapper chain and with the SysV calling convention.

For the first-pass runtime experiment, the argument names should be treated as:

- `arg0` = `this`
- `arg1` = selected-save discriminator / player-or-session integer
- `arg2` = first `CExoString&`
- `arg3` = second `CExoString&`
- `arg4` = flags / mode integer

The semantic meaning of `arg1` and `arg4` is not yet confirmed at runtime, but the register mapping is clear.

# CExoString layout

The x86_64 build confirms the following `CExoString` layout from disassembly:

- offset `0x0`  -> `char *` data pointer
- offset `0x8`  -> length
- offset `0xC`  -> capacity / auxiliary integer field

Evidence comes from:

- `CExoString::InitFromCharArray`
- `CExoString::Steal`
- `CExoString::Find`
- `CExoString::SubString`
- the string copy logic inside `CNWCMessage::SendPlayerToServerModule_LoadGame`

This means the two `CExoString&` parameters can likely be decoded safely by reading:

- the text pointer at offset `0`
- the length at offset `8`

That is enough to print the actual strings without modifying NWN.

# Observation method

The safest first method is a passive `bpftrace` uprobe on

`CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

Why `bpftrace` first:

- it is passive
- it can read entry arguments directly from CPU registers
- the bpftrace man page documents `arg0`, `arg1`, `arg2`, ... for uprobes
- it supports `reg()`, `str()`, and pointer casts
- it can decode the `CExoString` fields using the confirmed layout

The bpftrace man page also documents that `arg0`, `arg1`, ... are extracted from CPU registers for uprobes, and that `str()` can read user-space strings.

# Exact first experiment

Trace only `CClientExoApp::SendLoadGameRequest` and print:

- `pid`
- `tid`
- `cpu`
- `this`
- the selected-save integer / player-id-like argument
- the two `CExoString` payloads
- the trailing integer flag

Proposed manual command:

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)"
{
  printf("pid=%d tid=%d cpu=%d arg0=0x%lx arg1=0x%lx arg2=0x%lx arg3=0x%lx arg4=0x%lx obj2=%r obj3=%r\n",
         pid, tid, cpu,
         (uint64)arg0, (uint64)arg1, (uint64)arg2, (uint64)arg3, (uint64)arg4,
         buf(uptr((void *)arg2), 16),
         buf(uptr((void *)arg3), 16));
}'
```

The command above assumes the existing no-space hardlink path used by the perf tracing work. That avoids the original binary path with spaces and keeps the probe target stable.

If the quoted demangled uprobe spec is rejected by this bpftrace build, the smallest fallback is to switch the probe target to the known address for the same function:

- `0x637960`

That preserves the same argument-capture plan while avoiding symbol parsing issues.

# Expected output

For each invocation, the trace should print one line containing:

- process/thread identity
- CPU
- raw register values for `arg0` through `arg4`
- the first 16 bytes of the two `CExoString` objects

Expected ABI interpretation:

- `arg0` is the method `this` pointer
- `arg1` is the first integer argument
- `arg2` is the first `CExoString&`
- `arg3` is the second `CExoString&`
- `arg4` is the trailing integer argument

# Limitations

- `perf probe --vars` was not useful for these C++ methods in this build.
- The exact semantic meaning of the two strings is not yet proven by runtime capture, even though the memory layout is known.
- `bpftrace` must run with sufficient privileges and kernel support.
- The command above depends on the existing hardlink path being present, because the original NWN path contains a space.
- If the demangled uprobe spec fails, the fallback should be the address-based probe, not a larger framework rewrite.

# bpftrace string decoding issue

The raw-object experiment succeeded and strongly supports the `CExoString` layout hypothesis:

- `arg2` raw bytes looked like a `CExoString`
- `arg3` raw bytes looked like a `CExoString`
- the first 8 bytes were a pointer
- the next 4 bytes were a length
- the next 4 bytes were an auxiliary/capacity field

The failed decoding attempts were caused by bpftrace type handling rather than by the underlying data being absent.

Observed failure modes:

- `uint32` was not accepted in the attempted raw cast syntax when written as `u32`
- `str((char *)$s1p, 64)` was rejected by the parser
- the dynamic `str(pointer, length)` attempt aborted LLVM with:
  - `ICmpInst::AssertOK()`

Probable cause:

- the dynamic-length string call was mixing widths / signedness inside bpftrace's generated LLVM IR
- the fixed-length decode should use `str($ptr, 64)` directly on the integer pointer
- the tail fields should be read as `uint32`, not `u32`

Corrected staged commands:

## Stage A: raw object bytes only

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)"
{
  printf("pid=%d tid=%d cpu=%d arg0=0x%lx arg1=0x%lx arg2=0x%lx arg3=0x%lx arg4=0x%lx obj2=%r obj3=%r\n",
         pid, tid, cpu,
         (uint64)arg0, (uint64)arg1, (uint64)arg2, (uint64)arg3, (uint64)arg4,
         buf(uptr((void *)arg2), 16),
         buf(uptr((void *)arg3), 16));
}'
```

## Stage B: fixed-length text decode

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)"
{
  $s1p = *(uint64 *)arg2;
  $s2p = *(uint64 *)arg3;
  printf("pid=%d tid=%d cpu=%d arg0=0x%lx arg1=0x%lx arg2=0x%lx arg3=0x%lx arg4=0x%lx s1_ptr=0x%lx s2_ptr=0x%lx s1=%s s2=%s\n",
         pid, tid, cpu,
         (uint64)arg0, (uint64)arg1, (uint64)arg2, (uint64)arg3, (uint64)arg4,
         $s1p, $s2p,
         str($s1p, 64),
         str($s2p, 64));
}'
```

## Stage C: corrected field-width probe

The previous fixed-length attempt proved that the lengths must be read as 32-bit fields, not 64-bit fields.

The raw object bytes show:

- offset `0x0`  -> pointer
- offset `0x8`  -> 32-bit length
- offset `0xC`  -> 32-bit auxiliary/capacity

That means the next safe command should read the structure as two `uint32` values for the tail fields:

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)"
{
  $s1p = *(uint64 *)arg2;
  $s1len = *(uint32 *)(arg2 + 8);
  $s1cap = *(uint32 *)(arg2 + 12);
  $s2p = *(uint64 *)arg3;
  $s2len = *(uint32 *)(arg3 + 8);
  $s2cap = *(uint32 *)(arg3 + 12);
  printf("pid=%d tid=%d cpu=%d s1_ptr=0x%lx s1_len=%u s1_cap=%u s2_ptr=0x%lx s2_len=%u s2_cap=%u s1=%s s2=%s\n",
         pid, tid, cpu,
         $s1p, $s1len, $s1cap, $s2p, $s2len, $s2cap,
         str($s1p, 64),
         str($s2p, 64));
}'
```

This avoids the LLVM type-mixing issue caused by reading the tail fields as a single 64-bit value.

# Confidence level

High confidence:

- ABI mapping
- `CExoString` layout
- choice of first target function

Medium confidence:

- exact semantic names of the two `CExoString&` payloads
- exact meaning of the integer arguments

Low confidence:

- any broader multi-probe argument plan before the first one-function capture has been observed

# Recommended next manual step

Perform a single passive argument-capture experiment on `CClientExoApp::SendLoadGameRequest` and decode the two `CExoString` parameters from user memory.
