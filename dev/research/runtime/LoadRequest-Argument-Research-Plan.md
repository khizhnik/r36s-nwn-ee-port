# Goal

Determine what data is carried through the native load-request path so the custom NUI launcher can trigger the same flow without reimplementing the server-side load logic.

Confirmed native load-request chain:

1. `CPanelLoadGame::HandleOkButton`
2. `CPanelLoadGame::SendLoadGameRequest`
3. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`
4. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`
5. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

The selection lifecycle is already confirmed separately:

- `CPanelLoadSave::HandleSelectSaveGame`
- `CExoResMan::AddResourceDirectory`
- `CNWPortrait::ReplacePortraitTexture`

That lifecycle is useful context, but it does not answer what arguments are required to trigger the actual load request.

# Confirmed load-request chain

The chain is confirmed by the latest multi-probe load-request trace and by static symbol/disassembly inspection:

- `CPanelLoadGame::HandleOkButton()` is the earliest native UI callback on the load button path.
- `CPanelLoadGame::SendLoadGameRequest()` is the panel-layer dispatcher that prepares the request.
- `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` is a thin wrapper that forwards to the internal app layer.
- `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)` is the message-layer handoff.
- `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)` confirms the request reaches server-side load execution.

# Target functions

## 1. `CPanelLoadGame::SendLoadGameRequest()`

Known address: `0x6fa1d0`

Role:
- panel-level request builder
- selects a save slot from the save-list state
- fetches save metadata via `CSaveGameList`
- passes data onward to the client app layer

Likely data consumed:
- selected save index
- save name / folder string
- player password / connection password
- possibly flags derived from panel state

## 2. `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

Known address: `0x637960`

Role:
- public client wrapper
- forwards directly to `CClientExoAppInternal::SendLoadGameRequest`

Likely arguments:
- `unsigned int` is a selected-save discriminator or player/session identifier
- first `CExoString&` is likely the save directory/name payload
- second `CExoString&` is likely the player password or another request string
- `int` is likely a flag / mode / status value

## 3. `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`

Known address: `0x8027b0`

Role:
- serializes the load request into the client/server message layer

Likely arguments:
- same payload as the client wrapper, forwarded unchanged
- internal message code path copies both `CExoString` values from their backing structs

## 4. `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

Known address: `0x9fe780`

Role:
- server-side confirmation that the request reached actual load execution

Likely arguments:
- selected save discriminator / module context
- save name / directory string
- password / second string payload
- player pointer

## Supporting targets

### `CPanelLoadGame::GetSaveGameName()`

Known address: `0x6f9ef0`

Role:
- returns save metadata string derived from the selected slot
- used by `SendLoadGameRequest()` before the client handoff

### `CPanelLoadGame::GetPlayerPassword()`

Known address: `0x6f9820`

Role:
- returns password / access string used in the load path
- confirmed by static disassembly to read from config / panel state and build a `CExoString`

### `CPanelLoadGame::HandleOkButton()`

Known address: `0x6f99a0`

Role:
- UI callback entry point for the Load button
- contains branches for the load flow and other UI-side behavior

# ABI argument mapping

The x86_64 SysV calling convention applies to the public/native methods.

## `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

Likely register mapping at entry:

- `rdi` = `this`
- `rsi` = `unsigned int`
- `rdx` = `CExoString&` #1
- `rcx` = `CExoString&` #2
- `r8d` = `int`

This mapping is strongly supported by disassembly of the wrapper chain and by the known SysV ABI.

## `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)`

Likely register mapping:

- `rdi` = `this`
- `rsi` = `unsigned int`
- `rdx` = `CExoString&` #1
- `rcx` = `CExoString&` #2
- `r8d` = `int`

## `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)`

Likely register mapping:

- `rdi` = `this`
- `rsi` = `unsigned int`
- `rdx` = `CExoString&` #1
- `rcx` = `CExoString&` #2
- `r8` = `CNWSPlayer*`

## `CPanelLoadGame::SendLoadGameRequest()`

No explicit arguments, but it reads panel state and then constructs the outward call arguments.

# CExoString layout hypotheses

The `CExoString` layout is now confirmed by disassembly.

Confirmed fields on x86_64 build:

- offset `0x0`: `char*` data pointer
- offset `0x8`: length
- offset `0xc`: capacity / auxiliary integer field

Evidence:
- `InitFromCharArray`
- `Steal`
- `Find`
- `SubString`
- string-copy code in `CNWCMessage::SendPlayerToServerModule_LoadGame`

Interpretation:
- the two `CExoString&` parameters in the load-request chain can likely be decoded safely by reading the string pointer at offset `0` and the length at offset `8`
- the raw text payload is therefore observable without modifying NWN, as long as we only read user memory

Open question:
- which semantic payload each `CExoString&` carries in the final request path still needs runtime argument capture

# Candidate observation methods

## A. `bpftrace` uprobes with register reads

Pros:
- passive
- can read `rdi` / `rsi` / `rdx` / `rcx` / `r8`
- can dereference user pointers with `str()` or explicit user-memory reads
- well suited for a first argument-only probe

Cons:
- needs root / kernel support
- more awkward for C++ method symbols than raw perf tracepoints

Verdict:
- best candidate for a first argument-capture experiment

## B. `perf probe` with argument expressions

Pros:
- same perf stack already proven for event lifecycle tracing
- can be combined with existing helper infrastructure

Cons:
- `perf probe --vars` was not usable for these C++ method names in this build
- argument extraction on this binary is more fragile than bpftrace register reads

Verdict:
- possible fallback, but not the preferred first method

## C. `gdb` read-only breakpoint / commands

Pros:
- precise register and memory inspection

Cons:
- heavier, more intrusive, and explicitly deferred by the current request

Verdict:
- avoid for now

## D. `uftrace`

Pros:
- good for call flow and basic argument observation in some binaries

Cons:
- less certain for this C++ ABI / build / symbol set

Verdict:
- secondary fallback only

## E. `rr`

Pros:
- excellent for replay and exact inspection

Cons:
- intentionally out of scope for now

Verdict:
- not needed yet

# Safest next experiment

Trace only `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` first.

Why this function:
- it is the first client-side load-request boundary after the panel layer
- it has a stable, explicit signature
- its arguments are likely enough to reveal the save identifier and request strings we care about
- the function is a thin wrapper, so observation risk is low

Expected register mapping for the first experiment:

- `rdi` = `this`
- `rsi` = selected-save discriminator / session value
- `rdx` = first `CExoString&`
- `rcx` = second `CExoString&`
- `r8d` = flags / mode

# Exact proposed commands

No privileged tracing is run in this plan, but the next manual experiment should be shaped around a single argument-capture probe for `CClientExoApp::SendLoadGameRequest`.

Recommended next command family:

- use `bpftrace` uprobes with register reads
- decode the two `CExoString` values by reading their backing pointer and length
- print the raw selected index / integer argument alongside the strings

Example shape of the next manual probe:

- attach to the load-request function only
- print `rsi`, `rdx`, `rcx`, `r8`
- for each `CExoString*`, print the string pointer and string contents

# Risks / limits

- `perf probe --vars` is not a reliable path here for C++ methods in this build
- `CExoString` decoding is likely feasible, but the semantics of the two `CExoString&` values still need one runtime observation
- the exact meaning of the leading `unsigned int` and trailing `int` is not yet confirmed
- if the selected-save UI path and the load-request path are separated by additional state, the first experiment may only partially identify the payload

# Recommended next step

Perform a single passive argument-capture experiment on `CClientExoApp::SendLoadGameRequest` and decode the two `CExoString` parameters from user memory.

