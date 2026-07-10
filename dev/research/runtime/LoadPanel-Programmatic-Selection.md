# Goal
Determine the native way to programmatically select save index `N` in `CPanelLoadGame`, without patching NWN or writing memory.

# Known lifecycle
Confirmed native panel lifecycle:

```text
CreateLoadGamePanel()
    ↓
CPanelLoadGame::PostAttachmentInitialize()
    ↓
CPanelLoadSave::PostAttachmentInitialize(int)
    ↓
CPanelLoadGame::BuildButtonList()
    ↓
CPanelLoadSave::PopulateListWithSaveDirContents()
```

Confirmed selection/request chain:

```text
selection callback
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
    ↓
CClientExoApp::SendLoadGameRequest(...)
```

Two native code paths are especially important:

```text
CPanelLoadGame::PostAttachmentInitialize()
    → CGuiTabSet::SelectTab(0)
    → CPanelLoadSave::HandleSelectSaveGame(0)

CPanelLoadSave::DeleteSelectedSaveGame()
    → CGuiTabSet::SelectTab(N)
    → CPanelLoadSave::HandleSelectSaveGame(N)
```

Those two call sites strongly indicate the intended native way to move the panel to a different save entry.

# Meaning of index argument
The `int` argument to `CPanelLoadSave::HandleSelectSaveGame(int)` is the visible save-entry index / selection index, not the save-slot prefix itself.

Evidence:
- the first lifecycle call passes `0`
- `DeleteSelectedSaveGame()` uses the currently selected index, then reselects a neighbor and replays selection handling
- downstream load-request payloads correlate `arg1` with a small slot/index-like integer while `s1` is the save name suffix and `s2` is the module name

So the argument is the GUI/native selection index that identifies the chosen save row.

# Where selected index is stored
The selected index is stored inside the embedded `CGuiTabSet` object, not as a separate special-purpose setter field.

Layout evidence:
- `CPanelLoadGame::PostAttachmentInitialize()` passes `lea 0x948(%rbx)` into `CGuiTabSet::SelectTab(int)`
- `CGuiTabSet::SelectTab(int)` writes its current tab to offset `0x18` of the `CGuiTabSet`
- therefore the current selected index lives at `CPanelLoadGame + 0x948 + 0x18 = CPanelLoadGame + 0x960`

That resolves `this+0x960`:
- it is the `CGuiTabSet` current-tab field
- `CGuiTabSet::SelectTab(int)` is the writer

Required related state:
- `CPanelLoadGame + 0x948` = embedded `CGuiTabSet` / tab-selection widget
- `CPanelLoadGame + 0x950` = registered selection callback (`HandleSelectSaveGame`)
- `CPanelLoadGame + 0x958` = auxiliary callback/state slot initialized to zero
- `CPanelLoadGame + 0x13d0` = embedded `CSaveGameList`
- `CPanelLoadGame + 0xd50` = save-list translation table used by `SendLoadGameRequest()`

# Who writes selected index
The native writer is `CGuiTabSet::SelectTab(int)`.

Static evidence:
- `SelectTab(int)` stores the selected tab in the object’s current-tab field
- the load-panel lifecycle uses `SelectTab(0)` before invoking the selection callback
- the delete-flow uses `SelectTab(N)` before replaying `HandleSelectSaveGame(N)`

By contrast:
- `CPanelLoadSave::HandleSelectSaveGame(int)` refreshes preview / resources / portrait state
- it does not appear to be the primary writer for the stored selection index

# Callback registration
`CPanelLoadSave::PostAttachmentInitialize(int)` stores the selection callback into panel state:

- `CPanelLoadSave::HandleSelectSaveGame(int)` address is written to `CPanelLoadGame + 0x950`
- `CPanelLoadGame + 0x948` is used as the tab-selection object passed to `CGuiTabSet::SelectTab(int)`

Interpretation:
- the GUI selection machinery knows which callback to invoke
- the panel’s own setup code still explicitly calls `HandleSelectSaveGame(0)` for the initial selection
- native code also explicitly replays `HandleSelectSaveGame(N)` after changing selection in delete flow

# Candidate selection sequences

## A. Best native-correct sequence
```text
CGuiTabSet::SelectTab(N)
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
```
Rank: best.

Why:
- matches both the initial panel lifecycle and the delete/reselect code path
- updates the stored selected index in the tabset
- refreshes preview/resource state through the selection callback

## B. GUI callback path
```text
CGuiListBox::SetCurrentSelection(N)
    ↓
CGuiListBox::SetLineSelection(N, bool)
    ↓
generic callback / virtual dispatch
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
```
Rank: possible, but less direct for the load panel code examined here.

Why:
- generic listbox callback machinery exists
- but the load panel’s own confirmed selection setup uses `CGuiTabSet::SelectTab`, not a dedicated listbox setter

## C. Direct callback only
```text
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
```
Rank: incomplete.

Why:
- it refreshes selection-dependent state
- but by itself it does not establish the stored current-tab selection

## D. Direct field write
```text
write CPanelLoadGame + 0x960 = N
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
    ↓
CPanelLoadGame::SendLoadGameRequest()
```
Rank: worst.

Why:
- non-native
- unnecessary
- bypasses the actual GUI-selection primitive

# Feasibility ranking
1. `CGuiTabSet::SelectTab(N)` + `HandleSelectSaveGame(N)`  
   Most native and safest.
2. `CGuiListBox::SetCurrentSelection(N)` / `SetLineSelection(N)` callback path  
   Plausible generic GUI route, but not the one directly proven for the load-panel lifecycle.
3. `HandleSelectSaveGame(N)` alone  
   Useful for refresh, but not enough to prove stored selection changed.
4. Direct write to `+0x960`  
   Not recommended.

# Safest passive validation experiment
No runtime change is required to answer the static question above, but the smallest passive trace that would confirm the interpretation is:

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CGuiTabSet::SelectTab(int)"
{
  printf("SelectTab this=0x%lx idx=%d current=%u\n", (uint64)arg0, (int)arg1, *(uint32 *)(arg0 + 0x18));
}
uprobe:/tmp/nwmain-linux-hardlink:"CGuiListBox::SetCurrentSelection(int)"
{
  printf("SetCurrentSelection this=0x%lx idx=%d\n", (uint64)arg0, (int)arg1);
}
uprobe:/tmp/nwmain-linux-hardlink:"CGuiListBox::SetLineSelection(int, bool)"
{
  printf("SetLineSelection this=0x%lx idx=%d selected=%d\n", (uint64)arg0, (int)arg1, (int)arg2);
}
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadSave::HandleSelectSaveGame(int)"
{
  printf("HandleSelectSaveGame this=0x%lx idx=%d\n", (uint64)arg0, (int)arg1);
}
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::SendLoadGameRequest()"
{
  printf("SendLoadGameRequest this=0x%lx\n", (uint64)arg0);
}'
```

This would confirm that:
- `SelectTab(N)` updates the selection field at `+0x960`
- `HandleSelectSaveGame(N)` follows the selection change
- `SendLoadGameRequest()` sees the selected entry

# Conclusion
The best native way to select index `N` is:

```text
CGuiTabSet::SelectTab(N)
    ↓
CPanelLoadSave::HandleSelectSaveGame(N)
```

The `SelectTab(N)` step is required to update the stored selected index (`CPanelLoadGame + 0x960`, i.e. the `CGuiTabSet` current-tab field). `HandleSelectSaveGame(N)` alone is not enough as a complete native selection transition, because it is the refresh callback rather than the selection-state writer.

`this+0x960` is no longer unresolved: it is the embedded tabset’s current selection field.
