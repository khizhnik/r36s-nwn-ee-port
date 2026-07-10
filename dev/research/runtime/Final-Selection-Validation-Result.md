# Goal
Record the passive runtime validation of the native save-selection path and confirm whether the observed selection state flows into the load request.

# Command used
The validation used the passive `bpftrace` experiment from the prior note, tracing:

- `CGuiTabSet::SelectTab(int)`
- `CPanelLoadSave::HandleSelectSaveGame(int)`
- `CPanelLoadGame::SendLoadGameRequest()`

No new tracing was run for this update.

# Runtime evidence
Observed trace lines:

```text
SelectTab this=0x56171deb1488 idx=1 current=0
HandleSelectSaveGame this=0x56171deb0b40 idx=1 current=1
SendLoadGameRequest this=0x56171deb0b40 current=1

SelectTab this=0x56171dec3ec8 idx=2 current=0
HandleSelectSaveGame this=0x56171dec3580 idx=2 current=2
SendLoadGameRequest this=0x56171dec3580 current=2
```

Initial panel-open evidence:

```text
SelectTab ... idx=0 current=4294967295
HandleSelectSaveGame ... idx=0 current=0
```

# Confirmed sequence
The runtime evidence confirms the native chain:

```text
CGuiTabSet::SelectTab(N)
    ↓
updates current selection to N
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
    uses current selected index N
```

# What is now proven
The static model is now experimentally validated.

Specifically, the trace shows:

- `SelectTab(N)` updates the active selection state
- `HandleSelectSaveGame(N)` immediately follows selection changes
- `SendLoadGameRequest()` sees the final current selection

This is the strongest evidence so far that the native load panel already carries the exact selection state needed by the request path.

# Bridge implication
The custom NUI bridge should target this native sequence:

```text
CreateLoadGamePanel()
→ CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
→ CPanelLoadGame::SendLoadGameRequest()
```

That is the native sequence to reproduce, not a custom reimplementation of load-request payload construction.

# Remaining implementation question
How to call these native functions from the custom NUI bridge safely in-process.

That remains unresolved and should be treated as the next implementation-design question, not a reverse-engineering problem.
