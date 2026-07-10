# Goal
Determine whether a minimal native state-injection path exists for loading a selected save by reusing the live `CPanelLoadGame` instance rather than recreating the full object graph.

# Known state requirements
From earlier inspection:

- `CPanelLoadGame::SendLoadGameRequest()` reads `this+0x960` as the selected save index.
- `SendLoadGameRequest()` also depends on the embedded save-list state at `this+0x13d0` and the save-list index table at `this+0xd50`.
- The downstream request payload carries:
  - `arg1` as the numeric save slot / prefix-like value
  - `s1` as the save name / folder suffix
  - `s2` as the module name
  - `arg4` as a flags integer, observed as `0`

# Selected-index setter search
Static symbol and disassembly review did not surface a dedicated load-panel setter such as `SetSelectedSaveIndex()` or `SelectSave()` on `CPanelLoadGame`.

What *is* present:

- generic GUI selection APIs such as `CGuiTabSet::SelectTab(int)`
- generic list APIs such as `CGuiListBox::SetCurrentSelection(int)` and `CGuiListBox::SetItemIndex(int, int)`

Those are candidate ways the UI may drive selection, but they are not load-panel-specific setters.

# HandleSelectSaveGame relationship to 0x960
`CPanelLoadSave::HandleSelectSaveGame(int)` is the selection callback and clearly drives preview / resource refresh:

- it calls `CSaveGameList::GetSaveGameName(int)`
- it calls `CSaveGameList::GetSaveGameFileInfo(int)`
- it calls `CExoResMan::AddResourceDirectory(...)`
- it calls `CNWPortrait::ReplacePortraitTexture(...)`

The inspected disassembly did **not** show a direct store to `this+0x960` in `HandleSelectSaveGame(int)`.

That means:

- the callback is definitely part of the selection lifecycle
- but no dedicated write to the `selected save index` field was proven in the code path I inspected

# Save-list population path
`CPanelLoadGame::CreateLoadGamePanel(int)` creates and activates the panel, but it does not itself populate the save data.

Relevant lifecycle:

1. `CClientExoAppInternal::CreateLoadGamePanel(int)` allocates a fresh `CPanelLoadGame`.
2. `CPanelLoadGame::CPanelLoadGame(int)` constructs the base `CPanelLoadSave` portion and zeroes/initializes embedded state including the save-list area.
3. `CPanelLoadGame::PostAttachmentInitialize()` calls:
   - `CPanelLoadSave::PostAttachmentInitialize(int)`
   - `CPanelLoadGame::BuildButtonList()`
   - `CGuiTabSet::SelectTab(0)` when the panel has entries
   - `CPanelLoadSave::HandleSelectSaveGame(0)` for the initial selection
4. `CPanelLoadGame::BuildButtonList()` is just a tail-jump to `CPanelLoadSave::PopulateListWithSaveDirContents()`
5. `PopulateListWithSaveDirContents()` iterates the save list, calling:
   - `CSaveGameList::GetSaveGameName(int)`
   - `CSaveGameList::GetSaveGameFileInfo(int)`
   - `CPanelLoadSave::AddButton(...)`
6. `CSaveGameList::GetSaveGameList()` is the lower-level directory scanner / list builder that fills the save metadata backing the panel.

So:

- `CreateLoadGamePanel()` creates the live object
- `PostAttachmentInitialize()` and `BuildButtonList()` populate the save metadata
- the selection callback then applies the preview/resource refresh

# Decision table
| Requirement | Source | Can custom NUI satisfy? | How? |
|---|---|---:|---|
| live `CPanelLoadGame*` | `CreateLoadGamePanel(int)` / live panel owner in `CClientExoAppInternal+0xa0` | Yes | Let native UI create the panel, or reuse the reachable live panel while open |
| selected save index | `this+0x960` | Maybe | No dedicated setter found; likely must be driven through native selection flow or a generic UI selection API |
| save-list table `d50` | `this+0xd50` | Yes, indirectly | Populated as part of panel initialization / save-list build |
| embedded `CSaveGameList` `13d0` | `this+0x13d0` | Yes, indirectly | Constructed in `CPanelLoadSave` ctor and populated via `BuildButtonList()` / `PopulateListWithSaveDirContents()` |
| downstream payload | `CClientExoApp::SendLoadGameRequest(...)` | Not directly | Requires the panel state above plus the normal native request chain |

# Candidate injection sequences
## A. Preferred native path
`CreateLoadGamePanel()` → native selection flow (`SelectTab` / `HandleSelectSaveGame`) → `SendLoadGameRequest()`

This is the most realistic because it reuses the existing panel and does not require direct memory writes.

## B. Direct state write path
`CreateLoadGamePanel()` → write `this+0x960` directly → `SendLoadGameRequest()`

This is the smallest state mutation path in theory, but it is not currently supported by any observed native setter and would require code that we are not implementing here.

## C. Impossible without extra UI state
`CreateLoadGamePanel()` alone → `SendLoadGameRequest()`

Not realistic. The request function needs a populated save list and a meaningful selected index.

# Feasibility assessment
Minimal native state injection looks **plausible**, but only if the custom launcher can reuse an existing live `CPanelLoadGame` instance and then trigger the native selection path.

What is *not* yet justified:

- direct call to `SendLoadGameRequest()` with only `0x960` filled
- assuming a dedicated load-panel setter exists

What is justified:

- `CreateLoadGamePanel()` gives a live panel object
- panel initialization populates the save list
- selection is handled by existing UI flow

# Safest next experiment
Passive validation first, no writes:

- trace `CClientExoAppInternal::CreateLoadGamePanel(int)`
- trace `CPanelLoadGame::PostAttachmentInitialize()`
- trace `CPanelLoadSave::PopulateListWithSaveDirContents()`
- trace `CPanelLoadSave::HandleSelectSaveGame(int)`
- trace `CPanelLoadGame::SendLoadGameRequest()`

That will answer whether the live panel is created, populated, selected, and then used for the request in one coherent lifecycle.

# Risks
- No dedicated selected-index setter was found, so direct state injection may still require a generic GUI selection call rather than a field write.
- `HandleSelectSaveGame(int)` is selection/preview oriented and may not be the only state transition relevant to the final request.
- `CreateLoadGamePanel()` by itself is not enough; the list population path must also run.
- The panel may be reachable, but the custom launcher still cannot call native member functions directly without some bridging mechanism.

