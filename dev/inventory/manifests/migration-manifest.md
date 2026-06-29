# Migration Manifest

- Generated: 2026-06-27 23:14:56 EEST
- Source directories inspected: `/tmp`, `/home/khizhnik/Games/PortMaster/nwn-ee`, `SHADOW-TEST`, and all explicit project subtrees used in the bootstrap/NUI/tooling investigation.
- Destination root: `/home/khizhnik/Games/PortMaster/r36s-nwn-ee-port/dev`
- No files were deleted.
- `port/` was not modified.

## Artifact class notes

- `*.nss` = canonical source
- `*.ncs` = compiled artifact
- `*.mod` = test artifact

## Copied files count by category

- bootstrap/docs: 4
- bootstrap/modules: 4
- bootstrap/scripts: 5
- debug/logs: 1
- debug/scripts: 3
- external/aurora-borealius: 213
- external/nwn_script_comp: 3
- legacy/old-port-tree/config: 5
- legacy/old-port-tree/notes: 2
- legacy/old-port-tree/scripts: 6
- other: 3
- research/nui/builder-library: 6
- research/toolchain: 3
- toolset/scripts: 1
- toolset/userdir: 1

## Skipped files count by category

- AuroraBorealius `.git/`: 1 repository metadata tree skipped.
- AuroraBorealius generated `dist/`: skipped; build output not migrated.
- AuroraBorealius symlink target `aurora-borealis/aurora-borealis`: skipped; external target not migrated.
- Toolset runtime caches/autosaves/temp data in `/tmp/nwn-nui-toolset`: skipped; only the saved module artifact was preserved.
- Missing optional `/tmp` files: counted below as `missing_optional_files` in the manifest metadata section.
- Official game data trees (`data/`, `lang/`, `hak/`, `tlk/`, `movies/`, `music/`, `premium/`) were intentionally out of scope.

## Missing optional files from /tmp

- `/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_onenter_log.ncs`
- `/tmp/nwn-bootstrap-nui-window-test/modules/r36s_onenter_nui.ncs`
- `/tmp/nwn-bootstrap-launch-test/modules/r36s_bootstrap_work.mod`
- `/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_bootstrap_oncliententer.mod`
- `/tmp/nwn-bootstrap-test-03/modules/r36s_bootstrap_nui_window.mod`
- `/tmp/nwn-bootstrap-nui-window-test/modules/r36s_bootstrap_nui_window.mod`
- `/tmp/nwn-bootstrap-launch-test/modules/r36s_bootstrap_work.mod`
- `/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_bootstrap_oncliententer.mod`
- `/tmp/nwn-bootstrap-test-03/modules/r36s_bootstrap_nui_window.mod`
- `/tmp/nwn-bootstrap-nui-window-test/modules/r36s_bootstrap_nui_window.mod`

## Conflicts encountered

- None. Existing files in `dev/` were not overwritten during this pass.

## Confirmation

- `port/` was not modified.
- Originals were not deleted.

## Final dev tree (depth 3)

```text
# Final dev tree

/home/khizhnik/Games/PortMaster/r36s-nwn-ee-port/dev
├── baseline
├── bootstrap
│   ├── build
│   │   └── ML_Version.ncs
│   ├── docs
│   │   ├── BOOTSTRAP_MODULE.md
│   │   ├── LAUNCHER_PLAN.md
│   │   ├── NUI_BUILDER_API.md
│   │   └── NUI_COMPONENTS.md
│   ├── modules
│   │   ├── 00_r36s_bootstrap_clean.mod
│   │   ├── 01_r36s_bootstrap_work.mod
│   │   ├── 02_r36s_bootstrap_oncliententer.mod
│   │   └── 03_r36s_bootstrap_nui_window.mod
│   ├── scripts
│   │   ├── ML_Version.builder_poc_confirmed.nss
│   │   ├── ML_Version.hello_nui_working.nss
│   │   ├── ML_Version.nss
│   │   ├── r36s_onenter_log.nss
│   │   └── r36s_onenter_nui.nss
│   └── userdirs
├── debug
│   ├── crashreports
│   ├── input-keyboard-diagnose.sh
│   ├── logs
│   │   └── NUI_EXPERIMENT_LOG.txt
│   └── scripts
│       ├── input-keyboard-diagnose.sh
│       ├── run-nui-test.sh
│       └── show-keyboard.sh
├── docs
├── external
│   ├── aurora-borealius
│   │   ├── .cargo
│   │   ├── .gitignore
│   │   ├── AGENTS.md
│   │   ├── Cargo.lock
│   │   ├── Cargo.lock.bak
│   │   ├── Cargo.toml
│   │   ├── TOOLCHAIN_NOTES.md
│   │   ├── aurora-borealis
│   │   ├── dump_body_parts.rs
│   │   ├── dump_model.rs
│   │   ├── dump_tex.rs
│   │   ├── dump_tlk.rs
│   │   ├── list_models.rs
│   │   ├── nevercommand
│   │   ├── nevererf
│   │   ├── nwn-2da
│   │   ├── nwn-3d
│   │   ├── nwn-erf
│   │   ├── nwn-gamemodel
│   │   ├── nwn-gff
│   │   ├── nwn-script
│   │   ├── nwn-tileset
│   │   ├── nwn-tlk
│   │   ├── nwnsc.exe
│   │   ├── plan_area_tabs.md
│   │   ├── plans
│   │   ├── run_windows.bat
│   │   ├── run_windows.ps1
│   │   └── src
│   └── nwn_script_comp
│       ├── bin
│       └── neverwinter-x86_64-linux-gnu.zip
├── inventory
│   ├── artifacts.md
│   ├── checksums
│   ├── manifests
│   │   └── missing-optional-files.txt
│   ├── migrate-artifacts.sh
│   └── trees
│       └── final-dev.tree.txt
├── legacy
│   └── old-port-tree
│       ├── config
│       ├── notes
│       └── scripts
├── logs
├── modules
├── nui
│   ├── docs
│   └── sources
├── research
│   ├── nui
│   │   └── builder-library
│   └── toolchain
│       ├── 3d-viewport.md
│       ├── TOOLCHAIN_NOTES.md
│       └── plan_area_tabs.md
├── scripts
├── tools
│   └── show-keyboard.sh
├── toolset
│   ├── docs
│   ├── scripts
│   │   └── run-toolset.sh
│   └── userdir
│       └── modules
└── working

57 directories, 44 files
```

## git status --short

```text
AM .gitattributes
AM .gitignore
?? dev/
?? port/
```

## Next recommended step

- Create a compatibility wrapper and fix hardcoded paths so the new tree can be used without referring back to the scattered old locations.
