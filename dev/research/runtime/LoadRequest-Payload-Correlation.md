# Goal

Correlate the runtime payload observed in `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` with the actual PC harness save files so we can infer what the native load path expects from a custom launcher.

Observed runtime payloads:

1. `arg1 = 4`, `arg4 = 0`, `s1 = "888"`, `s2 = "The Prelude"`
2. `arg1 = 2`, `arg4 = 0`, `s1 = "23w"`, `s2 = "The Prelude"`

# Runtime payload observed

The passive bpftrace experiment decoded the arguments from:

`CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

Observed values:

- `arg1` changed between `4` and `2`
- `arg4` was `0` in both observations
- `s1` was `888` in one observation and `23w` in the other
- `s2` was `The Prelude` in both observations

The raw-object experiment also strongly supported the `CExoString` layout:

- offset `0x0` = pointer
- offset `0x8` = 32-bit length
- offset `0xC` = 32-bit auxiliary/capacity

# Harness save root

The PC harness uses:

`dev/pc/userdir`

for its isolated NWN userdir, and the save directory observed in this run is:

`dev/pc/userdir/saves`

This is confirmed by `dev/pc/scripts/run-nui-bootstrap.sh`, which launches NWN with:

- `-userdirectory "$USER_DIR"`
- `USER_DIR="$PC_DIR/userdir"`

On the save-request path, the script scans:

- `"$USER_DIR"/saves` when using the harness userdir

So the relevant save root for this research run is:

`dev/pc/userdir/saves`

# Files/directories inspected

Inspected harness and save-related paths:

- `dev/pc/scripts/run-nui-bootstrap.sh`
- `dev/pc/userdir/saves/000002 - 23w`
- `dev/pc/userdir/saves/000003 - 3234`
- `dev/pc/userdir/saves/000004 - 888`
- `dev/pc/userdir/development/r36s_saveindex.txt`

Key files in each save directory:

- `player.bic`
- `screen.tga`
- `portrait.tga`
- `module_uuid.txt`
- `savenfo.txt`
- `The Prelude.sav`

# Matches for "888"

Matched locations:

- directory name: `dev/pc/userdir/saves/000004 - 888`
- save title field in the generated saveindex line: `SAVE|000004 - 888|888|...`
- runtime payload: `s1 = "888"`

Metadata for that directory:

- `module_uuid.txt` contains the same UUID as the other saves:
  - `226fa48b-2960-439f-989c-7c4d3571dbfa`
- `savenfo.txt` contains:
  - `Senior Barracks`
- `The Prelude.sav` is present
- `screen.tga` is present
- `portrait.tga` is present
- `player.bic` is present

Interpretation:

- `888` is strongly supported as the save folder suffix / user-visible save name, not the module title and not the area title.

# Matches for "23w"

Matched locations:

- directory name: `dev/pc/userdir/saves/000002 - 23w`
- save title field in the generated saveindex line: `SAVE|000002 - 23w|23w|...`
- runtime payload: `s1 = "23w"`

Metadata for that directory:

- `module_uuid.txt` contains:
  - `226fa48b-2960-439f-989c-7c4d3571dbfa`
- `savenfo.txt` contains:
  - `Senior Barracks`
- `The Prelude.sav` is present
- `screen.tga` is present
- `portrait.tga` is present
- `player.bic` is present

Interpretation:

- `23w` is strongly supported as the save folder suffix / user-visible save name.

# Matches for "The Prelude"

Matched locations:

- file name: `dev/pc/userdir/saves/000004 - 888/The Prelude.sav`
- file name: `dev/pc/userdir/saves/000003 - 3234/The Prelude.sav`
- file name: `dev/pc/userdir/saves/000002 - 23w/The Prelude.sav`
- generated saveindex module field: `SAVE|...|...|...|The Prelude|...`
- runtime payload: `s2 = "The Prelude"`

Non-matches / negative evidence:

- `savenfo.txt` contains `Senior Barracks`, not `The Prelude`
- `module_uuid.txt` contains a UUID, not `The Prelude`

Interpretation:

- `The Prelude` is strongly supported as the module name / save title associated with the `.sav` file and the saveindex `module_name` field.

# Field interpretation

## `arg1`

Status: **hypothesis**, strongly supported

Likely meaning:

- numeric save identifier / slot prefix from the save directory name

Evidence:

- runtime values were `4` and `2`
- the corresponding save directories are `000004 - 888` and `000002 - 23w`
- the numeric prefix matches the observed integer

What is still unknown:

- whether this integer is a pure slot index, a player/session identifier, or another internal save discriminator

## `s1`

Status: **strongly supported**

Likely meaning:

- save folder suffix / user-visible save name

Evidence:

- runtime values were `888` and `23w`
- matching directories are `000004 - 888` and `000002 - 23w`
- the generated saveindex stores the suffix as the save name field

## `s2`

Status: **strongly supported**

Likely meaning:

- module name / module title

Evidence:

- runtime value was `The Prelude`
- the `.sav` file is named `The Prelude.sav`
- the generated saveindex stores `The Prelude` in the module_name field
- the value is stable across multiple save directories

## `arg4`

Status: **hypothesis**

Likely meaning:

- flags / mode / request option

Evidence:

- observed value was `0` in both samples

What is still unknown:

- whether `0` is a default flag, a boolean mode, or an internal status value

# Implications for custom NUI launcher

The custom launcher likely needs to reproduce, at minimum:

- the selected save identifier / slot prefix
- the user-visible save name / save folder suffix
- the module title / module name

The current wrapper already builds a saveindex file with fields that match these observations:

- folder
- save_name
- module_name

That means the custom NUI side is already very close to the native payload shape.

# Remaining unknowns

- the exact semantic meaning of `arg1`
- the exact semantic meaning of `arg4`
- whether `s1` is consumed as a folder suffix, save name, or a more specific internal identifier after it leaves `CClientExoApp::SendLoadGameRequest`
- whether `CPanelLoadGame::SendLoadGameRequest()` passes any additional state that is not visible in this one boundary

# Next experiment

Smallest next experiment:

- trace one more existing save entry with a unique `arg1`/folder prefix pair already present on disk
- confirm that the integer argument tracks the numeric folder prefix while `s1` tracks the suffix

The best candidate is the third existing save directory:

- `dev/pc/userdir/saves/000003 - 3234`

If the next trace shows:

- `arg1 = 3`
- `s1 = "3234"`
- `s2 = "The Prelude"`

then the current field interpretation becomes very strong without changing any save data.