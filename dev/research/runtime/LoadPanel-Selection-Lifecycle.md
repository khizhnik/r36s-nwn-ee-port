# Goal
Recover the exact native transition from "save list built" to "a save is selected" inside the Load panel lifecycle.

The question is not about actual loading. The question is:

```text
PopulateListWithSaveDirContents()
        ↓
?????????????????
        ↓
HandleSelectSaveGame()
```

We want the specific call that performs this transition and whether it is a direct call or a GUI callback path.

# Caller graph

## High-level lifecycle

```text
CClientExoAppInternal::CreateLoadGamePanel(int)
        ↓
CPanelLoadGame::CPanelLoadGame(int)
        ↓
CPanelLoadGame::PostAttachmentInitialize()
        ↓
CPanelLoadSave::PostAttachmentInitialize(int)
        ↓
CPanelLoadGame::BuildButtonList()
        ↓
CPanelLoadSave::PopulateListWithSaveDirContents()
        ↓
CPanelLoadGame::PostAttachmentInitialize()
        ↓
CGuiTabSet::SelectTab(0)
        ↓
CPanelLoadSave::HandleSelectSaveGame(0)
```

## Supporting lifecycle call sites

- `CMainMenuPanel::HandleLoadButton()`
- `CPlayModulePanel::HandleCancelButton()`
- `CPanelDeathMenu::OnLoadClose(int)`

These call `CClientExoApp::CreateLoadGamePanel(int)`, which forwards to the internal creator.

# Static findings

## 1. `CPanelLoadGame::PostAttachmentInitialize()`

This is the direct bridge between list construction and initial selection.

Disassembly shows:

1. It first calls the base initializer:
   - `CPanelLoadSave::PostAttachmentInitialize(int)`
2. It sets up the Load panel's own buttons.
3. It calls:
   - `CPanelLoadGame::BuildButtonList()`
4. After the list is available, it checks whether the panel has entries.
5. If entries exist, it does:
   - `CGuiTabSet::SelectTab(0)`
   - `CPanelLoadSave::HandleSelectSaveGame(0)`

This is the key point:

- the first selected-save transition is **direct**
- it is **not** routed through an additional generic callback just to get the initial selection

## 2. `CPanelLoadGame::BuildButtonList()`

This is a tail-jump to:

- `CPanelLoadSave::PopulateListWithSaveDirContents()`

So the BuildButtonList step is not a separate lifecycle stage. It is just the load-panel entry into the generic save-list population code.

## 3. `CPanelLoadSave::PostAttachmentInitialize(int)`

This base initializer does not select a save by itself, but it does set up the selection callback state for later UI interactions.

The disassembly shows stores to the panel object around:

- `0x948`
- `0x950`
- `0x958`
- `0x978`

The important part is that `0x950` is assigned the address of:

- `CPanelLoadSave::HandleSelectSaveGame(int)`

So the base initializer appears to register the selection handler for the live panel object.

Interpretation:

- the panel has a native callback slot for save selection
- later user-driven selection changes can use that callback state
- but the first transition after building the list is still done by the explicit call in `CPanelLoadGame::PostAttachmentInitialize()`

## 4. `CPanelLoadSave::PopulateListWithSaveDirContents()`

This function builds the visible save list:

- calls `CSaveGameList::GetSaveGameName(int)`
- calls `CSaveGameList::GetSaveGameFileInfo(int)`
- calls `CPanelLoadSave::AddButton(...)`

It does not itself call `HandleSelectSaveGame(int)`.

So the answer to the transition question is not inside `PopulateListWithSaveDirContents()` itself.

## 5. `CPanelLoadSave::HandleSelectSaveGame(int)`

This is the selection callback that refreshes:

- resource directory state
- portrait texture
- selection-dependent UI state

It is reachable from the initial panel lifecycle only after `PostAttachmentInitialize()` decides to select the first entry.

# Candidate GUI callback path

There is evidence of generic GUI selection machinery in the binary:

- `CGuiTabSet::SelectTab(int)`
- `CGuiListBox::SetCurrentSelection(int)`
- `CGuiListBox::SetLineSelection(int, bool)`
- `CGuiTreeview::HandleListboxSelect(int)`

These functions are real selection primitives in the engine, but for the first Load-panel selection they are not the primary bridge we need.

The direct, proven bridge is:

```text
PopulateListWithSaveDirContents()
        ↓
CPanelLoadGame::PostAttachmentInitialize()
        ↓
CGuiTabSet::SelectTab(0)
        ↓
CPanelLoadSave::HandleSelectSaveGame(0)
```

The GUI callback machinery is better viewed as supporting later user interaction rather than the initial panel bootstrap selection.

# What is confirmed directly by disasm

| Item | Status | Evidence |
|---|---|---|
| `BuildButtonList()` calls `PopulateListWithSaveDirContents()` | Confirmed | `CPanelLoadGame::BuildButtonList()` is a tail jump to `CPanelLoadSave::PopulateListWithSaveDirContents()` |
| `PostAttachmentInitialize()` triggers the first selection | Confirmed | It calls `CGuiTabSet::SelectTab(0)` and then `CPanelLoadSave::HandleSelectSaveGame(0)` when the panel has entries |
| `HandleSelectSaveGame()` is not called from `PopulateListWithSaveDirContents()` | Confirmed | No call edge from the population function itself |
| A generic selection callback is registered | Confirmed | `CPanelLoadSave::PostAttachmentInitialize(int)` stores the `HandleSelectSaveGame` address into panel state |
| `CGuiListBox` selection APIs exist | Confirmed | `SetCurrentSelection`, `SetLineSelection`, etc. |

# Lifecycle interpretation

The first selected-save state does **not** come from the population function.

Instead, the flow is:

1. Create and attach a live load panel.
2. Initialize the panel's base save-list UI state.
3. Populate the save list.
4. If there is at least one entry, explicitly select tab 0.
5. Immediately call `HandleSelectSaveGame(0)`.

That means the missing bridge is not a hidden listbox callback between list construction and selection.
It is the explicit call in `CPanelLoadGame::PostAttachmentInitialize()`.

# Conclusion

The exact call that connects the populated list to the selected-save state is:

```text
CPanelLoadGame::PostAttachmentInitialize()
    → CGuiTabSet::SelectTab(0)
    → CPanelLoadSave::HandleSelectSaveGame(0)
```

So the answer to the original question is:

- `PopulateListWithSaveDirContents()` builds the list
- `PostAttachmentInitialize()` performs the first selection
- `HandleSelectSaveGame(0)` is invoked directly, not via an extra callback hop for the initial lifecycle

The generic GUI callback path is still present for later interactions, but it is not required to explain the initial transition from "list built" to "selected save".

