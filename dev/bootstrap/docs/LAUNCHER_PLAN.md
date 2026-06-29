# R36S NUI Launcher Plan

## Strategic decision

Primary direction:
A. Bootstrap Launcher module

Parallel research:
B. Client screens / EE Browser / main menu / character select

## Why Bootstrap Launcher

- earliest documented path with module context
- can obtain player object
- can call `NuiCreate`
- compatible with confirmed builder API
- avoids relying on undocumented client UI hooks

## Why not Main Menu / EE Browser for now

- no confirmed NWScript context
- no confirmed `oPlayer`
- no confirmed way to call `NuiCreate`
- can still be researched later as direction B

## Phase A — Bootstrap Launcher

Goal:
Create a tiny module that behaves as a launcher shell, not as normal gameplay.

Hypothesis:
A minimal/blank module with a player object can open our builder-based NUI immediately and become the R36S launcher interface.

Steps:
1. Investigate minimal required module resources.
2. Create or identify tiny bootstrap module.
3. Add OnClientEnter or OnModuleLoad script that opens current builder PoC.
4. Launch via `+TestNewModule` or `+LoadNewModule`.
5. If character select is annoying, investigate `Mod_DefaultBic`.
6. Hide/minimize gameplay area later.
7. If confirmed, evolve UI into full R36S launcher.

Success criteria:
- module starts quickly
- no visible gameplay dependency or minimal black/empty area
- player object exists
- builder NUI opens immediately
- `NuiCol` menu renders
- no crash under software GL
- usable as launcher shell

## Phase B — Client Screen Research

Goal:
Study main menu / EE Browser / character select / server browser as client-side systems.

Questions:
- what resources control them
- whether JUI/GUI resources can be themed
- whether any script hook exists
- whether they can be useful later

Important:
Phase B must not block Phase A.

## Current recommendation

Start Phase A first.

## Bootstrap module creation paths

Path A: NWToolset via Wine
- immediate primary path
- good for first manual prototype
- creates valid module resources safely
- avoids hand-building ERF/GFF

Path B: AuroraBorealius / Rust toolchain
- parallel research path
- target for future reproducible automated builds
- promising pieces: `nwn-gamemodel`, `nwn-gff`, `nwn-erf`
- not immediate because Rust/Cargo is not available locally and ready-made CLI packer is not confirmed

Current decision:
Use Path A for first bootstrap module.
Keep Path B for future automation.

## Toolset path via Wine

- Use NWToolset as the preferred way to create the first bootstrap module.
- Reason: local CLI pack/unpack tools are missing.
- Toolset can create valid `module.ifo`, area, `git`, `gic`, and start location resources.
- This avoids hand-building ERF/GFF.
- Forum note: run from `bin/win32` and pass `-userdirectory`.

## Manual Toolset workflow

1. Run `run-toolset.sh`.
2. Create a new empty module.
3. Create one tiny area.
4. Set a start location.
5. Add module `OnClientEnter` script later.
6. Save as `r36s_launcher.mod`.
7. Later compile the launcher script and attach it.
