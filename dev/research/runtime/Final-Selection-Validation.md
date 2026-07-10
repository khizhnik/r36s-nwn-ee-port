# Goal
Validate, with one passive runtime experiment, whether native save selection flows through:

```text
CGuiTabSet::SelectTab(N)
    ↓
updates CPanelLoadGame + 0x960
    ↓
invokes CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
prepares CPanelLoadGame::SendLoadGameRequest() for the final selected save
```

This is a validation step only. It does not implement a bridge, write memory, patch NWN, or replace native behavior.

# Experiment
Trace exactly three native entry points:

1. `CGuiTabSet::SelectTab(int)`
2. `CPanelLoadSave::HandleSelectSaveGame(int)`
3. `CPanelLoadGame::SendLoadGameRequest()`

Use a single passive `bpftrace` one-liner that prints, for each hit:

- timestamp
- function name
- `this` pointer
- index argument, when present
- current selected index, if safely readable

## Proposed command

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CGuiTabSet::SelectTab(int)"
{
  printf("%lld SelectTab this=0x%lx idx=%ld current=%u\n",
         nsecs, (uint64)arg0, arg1, *(uint32 *)(arg0 + 0x18));
}
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadSave::HandleSelectSaveGame(int)"
{
  printf("%lld HandleSelectSaveGame this=0x%lx idx=%ld current=%u\n",
         nsecs, (uint64)arg0, arg1, *(uint32 *)(arg0 + 0x960));
}
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::SendLoadGameRequest()"
{
  printf("%lld SendLoadGameRequest this=0x%lx current=%u\n",
         nsecs, (uint64)arg0, *(uint32 *)(arg0 + 0x960));
}'
```

# User actions
Perform the following in order, with a short pause between each click so the output is easy to read:

1. Open the native Load panel.
2. Click save `#0`.
3. Click save `#3`.
4. Click save `#5`.
5. Press the native `Load` button.

Important:
- The panel may already start on `#0`; that first click is still useful as a baseline.
- Do not use any custom launcher bridge for this test.

# Success criteria
The experiment is successful if the trace shows:

1. `SelectTab(0)` / `HandleSelectSaveGame(0)` on panel open.
2. Subsequent clicks produce `SelectTab(3)` → `HandleSelectSaveGame(3)`.
3. Subsequent clicks produce `SelectTab(5)` → `HandleSelectSaveGame(5)`.
4. The final `SendLoadGameRequest()` reports current selected index `5`.

This would prove that:
- selection state updates through the GUI selection path
- the final chosen row is the one used for the native load request

If the trace instead shows:
- `HandleSelectSaveGame(N)` without a matching `SelectTab(N)`, or
- `SendLoadGameRequest()` with a different final index than the last click,

then the hypothesis is not fully validated.

# Interpretation
If the expected sequence appears, then:

> The static model is now experimentally validated.

That means the native selection path can be trusted as:

```text
SelectTab(N)
    ↓
HandleSelectSaveGame(N)
    ↓
SendLoadGameRequest()
```

# Risks / limits
- The `current` field is read directly from live process memory; if the object layout changes, the read could become invalid.
- The output uses a raw timestamp (`nsecs`) rather than wall-clock time.
- This trace validates the selection-to-request path, not the save loading implementation itself.
