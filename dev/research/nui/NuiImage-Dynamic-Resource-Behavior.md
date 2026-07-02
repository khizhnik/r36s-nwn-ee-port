# Goal

Determine whether `NuiImage()` can display an image that is created or replaced **after** NWN:EE has already started, or whether the Resource Manager effectively locks image visibility at startup.

This note only covers the image-loading behavior observed in the local R36S / PC dev environment.

# Environment

- Repository: `r36s-nwn-ee-port`
- NWN userdir used by the PC harness: `dev/pc/userdir`
- Base game install: Steam NWN:EE under `~/.steam/debian-installation/steamapps/common/Neverwinter Nights`
- Existing confirmed NUI image support:
  - built-in portrait `po_exornova_h`
  - save screenshot staged as `r36s_screen`
- Candidate TGA source used for this experiment:
  - original save screenshot: `~/.local/share/Neverwinter Nights/saves/000002 - sss/screen.tga`
  - replacement test image: `/tmp/r36s_screen_alt.tga`

The isolated test used:
- `dev/bootstrap/scripts/r36s_nimgtest.nss`
- `dev/bootstrap/scripts/r36s_nimgrfsh.nss`

# Experiments performed

## Phase 1: Static baseline, image present before NWN starts

Setup:
- Copied `screen.tga` into `dev/pc/userdir/development/r36s_screen.tga` **before** launching NWN.
- Ran the isolated NuiImage test.

Observed:
- `po_exornova_h` rendered.
- `r36s_screen` rendered.
- The captured window shows the original save screenshot image in the candidate slot.

Result: **PASS**

## Phase 2: Replace the same filename after NWN has already started

Setup:
- While NWN was already running, replaced:
  - `dev/pc/userdir/development/r36s_screen.tga`
  with a visually different TGA:
  - `/tmp/r36s_screen_alt.tga`
- Attempted to trigger a reopen of the isolated NuiImage test window.

Observed:
- The harness log contains only one `R36S_NUI_IMAGE_TEST_OPEN` entry for the run.
- No second open event was logged.
- The captured window after the file replacement still displayed the original save screenshot image, not the green `ALT` replacement.

Result: **INCONCLUSIVE**

Reason:
- The post-start file replacement did not produce an observed visible update.
- However, the test did not successfully prove that the test window was reopened after the replacement, so this does not conclusively prove cache behavior.

## Phase 3: Alternate locations (`development/`, `override/`, `portraits/`)

Not run in this pass.

Result: **NOT RUN**

## Phase 4: New resref while the game is already running

Not run in this pass.

Result: **NOT RUN**

## Phase 5: Delete and recopy the same file

Not run in this pass.

Result: **NOT RUN**

# Screenshots

- Baseline static render:
  - `dev/research/nui/screenshots/nui-image-static-baseline-window.png`
- Post-replacement capture:
  - `dev/research/nui/screenshots/nui-image-static-after-window.png`

The two captures show the candidate area remaining on the original save screenshot image in this run.

# Results

### PASS
- `NuiImage()` renders the built-in portrait `po_exornova_h`.
- `NuiImage()` renders the save screenshot when `r36s_screen.tga` is staged before NWN starts.

### INCONCLUSIVE
- Replacing `r36s_screen.tga` after NWN startup did not produce an observed visual change in the same session.
- The isolated reopen path did not log a second `R36S_NUI_IMAGE_TEST_OPEN`, so the experiment did not conclusively prove whether the Resource Manager cached the image or whether the reopen command failed.

### FAIL
- None established from this pass.

# Confirmed facts

✓ `NuiImage()` can display arbitrary TGA images when the resource is present before NWN starts.

✓ `NuiImage()` accepts bare resrefs.

✓ Images do not need to be portraits.

✓ A save screenshot (`screen.tga`) can be rendered as a NuiImage resource when exposed as `r36s_screen` before startup.

✓ In this run, replacing the same filename after startup did not yield an observed visual update.

## Recommendations

- For production use, the safest wrapper design is still to stage any preview TGA before NWN starts.
- Do not assume that a TGA copied into `development/` after the client is already running will be visible to `NuiImage()`.
- If live updates are required later, test a stronger reopen path or a different resource distribution mechanism before depending on post-start file replacement.
- For save previews, keep the wrapper as the metadata/image source and treat the NUI layer as a reader of already-prepared assets, not as a live filesystem watcher.
