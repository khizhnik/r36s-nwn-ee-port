# Goal
Define the smallest stable bridge API for the PC-harness native load prototype.

The bridge API must expose one concrete operation now:

```text
LoadSaveByIndex(int index)
```

It should reuse the confirmed native NWN load sequence instead of reconstructing payloads manually:

```text
CreateLoadGamePanel()
→ CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
→ CPanelLoadGame::SendLoadGameRequest()
```

This document defines the internal API shape and responsibilities only. It does not implement the bridge, transport, or native calls.

# Proposed public API

## Minimal entry point
```cpp
BridgeResult LoadSaveByIndex(int index);
```

This is the single public operation the custom NUI side can eventually invoke through whatever transport is chosen later.

## Result model
Keep the first result model small and explicit:

```cpp
enum class BridgeStatus {
    Ok,
    InvalidIndex,
    NativeSymbolsMissing,
    AppPointerMissing,
    PanelMissing,
    SelectionFailed,
    LoadRequestFailed,
    UnsupportedBinary,
};

struct BridgeResult {
    BridgeStatus status;
    const char* diagnostic; // short, stable, log-friendly message

    // Optional for logs only, not required for control flow.
    void* client_internal = nullptr;
    void* panel = nullptr;
    void* tabset = nullptr;
};
```

If the implementation later needs richer diagnostics, it can extend the internal struct without changing the public semantic contract of `LoadSaveByIndex(int)`.

# API semantics

`LoadSaveByIndex(int index)` means:

1. ensure the native load panel exists
2. resolve the live `CPanelLoadGame*`
3. select save index `index` via the native selection writer
4. refresh selection state through the native callback
5. trigger the native load request path

Fail closed:
- do nothing if the index is invalid
- do nothing if required symbols or pointers are missing
- do not guess if selection state cannot be verified
- do not call `SendLoadGameRequest()` if selection failed

# Minimal responsibility split

Keep the bridge as four small layers.

## `bridge_api`
Public stable interface.

Responsibilities:
- expose `LoadSaveByIndex(int index)`
- validate the high-level request
- coordinate the resolver, dispatcher, and logger
- return `BridgeResult`

## `native_resolver`
Resolve symbols and live pointers.

Responsibilities:
- locate `CClientExoApp::CreateLoadGamePanel(int)`
- locate `CGuiTabSet::SelectTab(int)`
- locate `CPanelLoadSave::HandleSelectSaveGame(int)`
- locate `CPanelLoadGame::SendLoadGameRequest()`
- resolve `g_pAppManager`
- resolve `CClientExoAppInternal*`
- resolve live `CPanelLoadGame*` from `internal + 0xa0`
- resolve tabset pointer from `panel + 0x948`

## `native_dispatch`
Perform the native call sequence.

Responsibilities:
- call `CreateLoadGamePanel()` if needed
- call `SelectTab(index)`
- verify selection state if safely readable
- call `HandleSelectSaveGame(index)`
- call `SendLoadGameRequest()`

## `bridge_log`
Write human-readable diagnostics.

Responsibilities:
- log request index
- log resolved native pointers
- log each native call boundary
- log failures with one-line reasons
- log the final status

# Required native dependencies

The bridge depends on the following confirmed native symbols and objects:

## Required symbols
- `CClientExoApp::CreateLoadGamePanel(int)`
- `CGuiTabSet::SelectTab(int)`
- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadGame::SendLoadGameRequest()`

## Required live objects / offsets
- live `CPanelLoadGame*`
- `CClientExoAppInternal+0xa0` = live load-panel owner
- `CPanelLoadGame+0x948` = embedded `CGuiTabSet`
- `CPanelLoadGame+0x960` = current selected index

## Strongly helpful but not strictly required for the first API contract
- `CClientExoApp::CreateLoadGamePanel(int)` as the panel-creation path
- `CClientExoAppInternal::CreateLoadGamePanel(int)` as the implementation path behind the public entry

# Native dispatch contract

The bridge should perform native calls in this order:

```text
ensure panel exists
→ resolve live CPanelLoadGame*
→ resolve panel+0x948 tabset
→ CGuiTabSet::SelectTab(index)
→ read/verify panel+0x960
→ CPanelLoadSave::HandleSelectSaveGame(index)
→ CPanelLoadGame::SendLoadGameRequest()
```

If any step fails, abort and return a failure `BridgeStatus`.

# Minimum inputs and outputs

## Input
- `index`

## Output
- `BridgeStatus`
- short diagnostic string
- optional native pointers for logs only

This is intentionally narrow so the bridge logic can later be reused with a different transport without changing semantics.

# Fail-closed behavior

The API must reject:
- negative index
- missing symbols
- null client internal pointer
- null live load panel
- null tabset pointer
- unsupported binary version
- unreadable or inconsistent selection state

The API must not:
- write memory
- guess selection state
- call `SendLoadGameRequest()` when selection failed
- assume the panel exists unless it has been verified

# PC harness MVP test scenario

Suggested first end-to-end test:

1. Start NWN on the PC harness with the bridge loaded.
2. Open the native Load panel manually.
3. Call `LoadSaveByIndex(1)`.
4. Verify the native request path starts.
5. Confirm with the existing passive tracing notes if needed.

The point of the MVP is to prove that the API can steer the native pipeline, not to replace or reimplement payload construction.

# Transport separation

The bridge API is not the transport.

The transport can change later without changing `LoadSaveByIndex(int)` semantics.

Possible future transports:
- simple FIFO
- UNIX domain socket
- script-triggered IPC
- NUI event bridge

For now, transport is out of scope.

# Proposed minimal file layout

```text
dev/pc/bridge/
  bridge_api.h
  bridge_api.cpp
  native_resolver.h
  native_resolver.cpp
  native_dispatch.h
  native_dispatch.cpp
  bridge_log.h
  bridge_log.cpp
```

This layout is intentionally small:
- `bridge_api` defines the stable interface
- `native_resolver` resolves symbols and object pointers
- `native_dispatch` performs the native calls
- `bridge_log` records success/failure steps

# Open risks

- whether the bridge should create the load panel itself or require the user to open it first
- whether selection validity should be checked only against the live tabset or also against visible save count
- whether the panel stays live long enough for the bridge command to arrive
- whether binary/version drift affects symbol resolution or offsets

These are implementation risks, not design blockers.

# Conclusion

The smallest useful public API is:

```cpp
BridgeResult LoadSaveByIndex(int index);
```

with a fail-closed internal contract that resolves the live load panel, selects the requested row natively, refreshes the selection state, and then calls `SendLoadGameRequest()`.

This is the right boundary for the first prototype because it keeps the transport replaceable and keeps all native-call logic in one place.
