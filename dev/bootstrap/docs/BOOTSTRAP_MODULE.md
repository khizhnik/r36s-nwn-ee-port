# Bootstrap Module

## Baseline

- Baseline module path: `/tmp/nwn-nui-toolset/modules/r36s_bootstrap_clean.mod`
- Archived baseline: `SHADOW-TEST/BOOTSTRAP_MODULES/00_r36s_bootstrap_clean.mod`
- Working copy: `SHADOW-TEST/BOOTSTRAP_MODULES/01_r36s_bootstrap_work.mod`
- File size: `20608 bytes`
- Timestamp: `2026-06-27 14:41:31.007628476 +0300`

## Toolset status

- NWToolset successfully runs on the host through Wine.
- Codex sandbox cannot reliably execute Wine GUI applications.

## Checkpoint 1 — clean module launch test

- Test module: `/tmp/nwn-bootstrap-launch-test/modules/r36s_bootstrap_work.mod`
- Source working copy: `SHADOW-TEST/BOOTSTRAP_MODULES/01_r36s_bootstrap_work.mod`

Command used:

```bash
cd "/home/khizhnik/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86"

timeout 60s env DISPLAY=:0 \
  LIBGL_ALWAYS_SOFTWARE=1 \
  MESA_LOADER_DRIVER_OVERRIDE=llvmpipe \
  ./nwmain-linux \
  -userdirectory "/tmp/nwn-bootstrap-launch-test" \
  +TestNewModule "r36s_bootstrap_work"
```

- Result: successful launch test.
- The engine loaded `r36s_bootstrap_work` and reached `Module Loaded` / `Module Running`.
- No module contents were modified for this test.

## Checkpoint 0

- `00_r36s_bootstrap_clean.mod` is immutable.
- All future experiments must be performed only on `01_r36s_bootstrap_work.mod`.
- If any experiment corrupts the working module, recreate it by copying the clean baseline again.
- Never modify the baseline.

## Module structure

To be filled after the first inspection of the saved module contents.

## Mandatory resources

Confirmed only after inspection.

## Optional resources

Confirmed only after inspection.

## Unknown resources

Anything not yet proven from the saved module contents.

## Launch flow

```
Start Game
    ↓
Load r36s_launcher.mod
    ↓
Player object exists
    ↓
OnClientEnter
    ↓
Builder NUI
```

## Next planned step

Inspect and attach `OnClientEnter` on the working copy only.

## Checkpoint 2 — OnClientEnter bootstrap proof

### Status

- Baseline remains immutable.
- Checkpoint 2 uses a new working copy only.
- The working `.mod` has not been modified yet.

### Test artifacts

- Working module copy: `SHADOW-TEST/BOOTSTRAP_MODULES/02_r36s_bootstrap_oncliententer.mod`
- Test userdir copy: `/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_bootstrap_oncliententer.mod`
- Script source: `SHADOW-TEST/NUI_BOOTSTRAP/scripts/r36s_onenter_log.nss`
- Compiled script: `/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_onenter_log.ncs`

### Module resource inventory

Confirmed from static inspection of the saved module:

- `module.ifo`
- `area001.are`
- `area001.git`
- module script field set present in `module.ifo`

Observed module.ifo field names in the saved archive strings:

- `Mod_OnHeartbeat`
- `Mod_OnModLoad`
- `Mod_OnModStart`
- `Mod_OnClientEnter`
- `Mod_OnClientLeave`
- `Mod_OnActvtItem`
- `Mod_OnAcquirItem`
- `Mod_OnUsrDefined`
- `Mod_OnUnAqreItem`
- `Mod_OnPlrDeath`
- `Mod_OnPlrDying`
- `Mod_OnPlrEqItm`
- `Mod_OnPlrLvlUp`
- `Mod_OnSpawnBtnDn`
- `Mod_OnPlrRest`
- `Mod_OnPlrUnEqItm`
- `Mod_OnCutsnAbort`
- `Mod_OnPlrChat`
- `Mod_OnPlrTarget`
- `Mod_OnPlrGuiEvt`
- `Mod_OnPlrTileAct`
- `Mod_OnNuiEvent`

### OnClientEnter field identification result

- The saved module strings show `Mod_OnClientEnter` in the archive.
- The AuroraBorealis source currently models a player-entry field as `Mod_OnPlayerEnter`.
- For checkpoint-2 modification work, the exact archive field to inspect/attach is `Mod_OnClientEnter`, based on the saved module strings.

### Script compile result

- `r36s_onenter_log.nss` compiled successfully to `r36s_onenter_log.ncs`.
- The script is ready for later attachment, but is not yet embedded in the module.

### Proposed exact modification plan

1. Open `02_r36s_bootstrap_oncliententer.mod`.
2. Inspect the `module.ifo` GFF field list.
3. Set `Mod_OnClientEnter` to `r36s_onenter_log`.
4. Save the modified module as a new working checkpoint copy.
5. Launch only the new checkpoint copy later, after attachment is confirmed.

## Checkpoint 3 — OnClientEnter Builder NUI window

### Status

- Checkpoint 3 uses a fresh copy only.
- The baseline remains immutable.
- The checkpoint-3 `.mod` has not been modified yet.
- The builder-based NUI script is compiled and ready.

### Test artifacts

- Working module copy: `SHADOW-TEST/BOOTSTRAP_MODULES/03_r36s_bootstrap_nui_window.mod`
- Test userdir copy: `/tmp/nwn-bootstrap-nui-window-test/modules/r36s_bootstrap_nui_window.mod`
- Script source: `SHADOW-TEST/NUI_BOOTSTRAP/scripts/r36s_onenter_nui.nss`
- Compiled script: `/tmp/nwn-bootstrap-nui-window-test/modules/r36s_onenter_nui.ncs`

### Script behavior

- Uses `#include "nw_inc_nui"`.
- Reads `GetEnteringObject()`.
- Logs:
  - `R36S_BOOTSTRAP_NUI_ONCLIENTENTER`
  - `R36S_BOOTSTRAP_NUI_ENTERING_VALID`
  - `R36S_BOOTSTRAP_NUI_ENTERING_IS_PC`
  - `R36S_BOOTSTRAP_NUI_TOKEN`
- If the entering object is a PC, it creates a builder-based NUI window with:
  - title: `R36S BOOTSTRAP`
  - `NuiCol`
  - `NuiLabel("Bootstrap module OK")`
  - `NuiRow`
  - `NuiButton("OK")`
  - `NuiSpacer()`
  - `NuiButton("Cancel")`

### Compile result

- `r36s_onenter_nui.nss` compiled successfully to `r36s_onenter_nui.ncs`.
- The script is ready for attachment, but the module archive has not yet been changed.

### Module field identification result

- Static inspection of the saved module archive shows module.ifo hook fields including `Mod_OnClientEnter`.
- That is the field to attach for this checkpoint.

### Proposed exact modification plan

1. Open `03_r36s_bootstrap_nui_window.mod`.
2. Inspect `module.ifo` in the module archive.
3. Set `Mod_OnClientEnter` to `r36s_onenter_nui`.
4. Save the modified module as a new checkpoint copy.
5. Launch only that new checkpoint copy later, after attachment is confirmed.

### Manual workflow fallback

- If a safe non-GUI modification path is not confirmed, use NWToolset manually instead:
  1. Open `03_r36s_bootstrap_nui_window.mod`.
  2. Import or add `r36s_onenter_nui.ncs`.
  3. Set `Module Properties -> Events -> OnClientEnter = r36s_onenter_nui`.
  4. Save as a new checkpoint copy.
