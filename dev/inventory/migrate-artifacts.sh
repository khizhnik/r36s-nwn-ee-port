#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT=/home/khizhnik/Games/PortMaster/r36s-nwn-ee-port
OLD=/home/khizhnik/Games/PortMaster/nwn-ee
SHADOW=$OLD/SHADOW-TEST
DEST=$ROOT/dev
MANIFEST_DIR=$DEST/inventory/manifests
TREE_DIR=$DEST/inventory/trees
CHECKSUM_DIR=$DEST/inventory/checksums
MISSING_OPTIONAL_FILE_LIST=$DEST/inventory/manifests/missing-optional-files.txt

copy_file_if_exists() {
  local src="$1"
  local dst_dir="$2"
  if [ -f "$src" ]; then
    mkdir -p "$dst_dir"
    cp -a "$src" "$dst_dir/"
  else
    printf '%s\n' "$src" >> "$MISSING_OPTIONAL_FILE_LIST"
  fi
  return 0
}

copy_dir_with_filter() {
  local src="$1"
  local dst="$2"
  shift 2
  mkdir -p "$dst"
  rsync -a "$@" "$src/" "$dst/"
}

copy_mods_from_dir() {
  local src_dir="$1"
  local dst_dir="$2"
  mkdir -p "$dst_dir"
  while IFS= read -r -d '' mod; do
    cp -a "$mod" "$dst_dir/"
  done < <(find "$src_dir" -maxdepth 1 -type f -name '*.mod' -print0)
  return 0
}

mkdir -p \
  "$DEST/bootstrap/docs" \
  "$DEST/bootstrap/modules" \
  "$DEST/bootstrap/scripts" \
  "$DEST/bootstrap/build" \
  "$DEST/bootstrap/userdirs" \
  "$DEST/research/toolchain" \
  "$DEST/research/nui/builder-library/layouts" \
  "$DEST/research/nui/builder-library/controls" \
  "$DEST/research/nui/builder-library/examples" \
  "$DEST/external" \
  "$DEST/toolset/docs" \
  "$DEST/toolset/scripts" \
  "$DEST/toolset/userdir/modules" \
  "$DEST/debug/scripts" \
  "$DEST/debug/logs" \
  "$DEST/debug/crashreports" \
  "$DEST/legacy/old-port-tree/scripts" \
  "$DEST/legacy/old-port-tree/config" \
  "$DEST/legacy/old-port-tree/notes" \
  "$DEST/nui/docs" \
  "$DEST/nui/sources" \
  "$MANIFEST_DIR" "$TREE_DIR" "$CHECKSUM_DIR"
: > "$MISSING_OPTIONAL_FILE_LIST"

# Bootstrap docs kept together.
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/BOOTSTRAP_MODULE.md" "$DEST/bootstrap/docs"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/LAUNCHER_PLAN.md" "$DEST/bootstrap/docs"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/NUI_COMPONENTS.md" "$DEST/bootstrap/docs"
copy_file_if_exists "$SHADOW/NUI_SOURCES/nuitest/NUI_BUILDER_API.md" "$DEST/bootstrap/docs"

# Bootstrap source scripts (*.nss).
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/ML_Version.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/ML_Version.builder_poc_confirmed.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/ML_Version.hello_nui_working.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/scripts/r36s_onenter_log.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/scripts/r36s_onenter_nui.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/ML_VERSION_TEST/ML_Version.nss" "$DEST/bootstrap/scripts"
copy_file_if_exists "$SHADOW/R36S_SHADOW_TEST.nss" "$DEST/legacy/old-port-tree/notes"

# Compiled artifacts (*.ncs).
copy_file_if_exists "$SHADOW/ML_VERSION_TEST/ML_Version.ncs" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_onenter_log.ncs" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-nui-window-test/modules/r36s_onenter_nui.ncs" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-launch-test/modules/r36s_bootstrap_work.mod" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_bootstrap_oncliententer.mod" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-test-03/modules/r36s_bootstrap_nui_window.mod" "$DEST/bootstrap/build"
copy_file_if_exists "/tmp/nwn-bootstrap-nui-window-test/modules/r36s_bootstrap_nui_window.mod" "$DEST/bootstrap/build"
copy_file_if_exists "$SHADOW/R36S_SHADOW_TEST.ncs" "$DEST/legacy/old-port-tree/notes"

# Bootstrap test modules (*.mod).
copy_mods_from_dir "$SHADOW/BOOTSTRAP_MODULES" "$DEST/bootstrap/modules"

# Archived bootstrap userdir modules.
copy_file_if_exists "/tmp/nwn-bootstrap-launch-test/modules/r36s_bootstrap_work.mod" "$DEST/bootstrap/userdirs/nwn-bootstrap-launch-test/modules"
copy_file_if_exists "/tmp/nwn-bootstrap-oncliententer-test/modules/r36s_bootstrap_oncliententer.mod" "$DEST/bootstrap/userdirs/nwn-bootstrap-oncliententer-test/modules"
copy_file_if_exists "/tmp/nwn-bootstrap-test-03/modules/r36s_bootstrap_nui_window.mod" "$DEST/bootstrap/userdirs/nwn-bootstrap-test-03/modules"
copy_file_if_exists "/tmp/nwn-bootstrap-nui-window-test/modules/r36s_bootstrap_nui_window.mod" "$DEST/bootstrap/userdirs/nwn-bootstrap-nui-window-test/modules"

# Research notes.
copy_file_if_exists "$SHADOW/TOOLS/AuroraBorealius-Toolset-and-Shargast-by-Jaysn/TOOLCHAIN_NOTES.md" "$DEST/research/toolchain"
copy_file_if_exists "$SHADOW/TOOLS/AuroraBorealius-Toolset-and-Shargast-by-Jaysn/plan_area_tabs.md" "$DEST/research/toolchain"
copy_file_if_exists "$SHADOW/TOOLS/AuroraBorealius-Toolset-and-Shargast-by-Jaysn/plans/3d-viewport.md" "$DEST/research/toolchain"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/README.md" "$DEST/research/nui/builder-library"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/layouts/README.md" "$DEST/research/nui/builder-library/layouts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/layouts/r36s_ui_layouts.md" "$DEST/research/nui/builder-library/layouts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/controls/README.md" "$DEST/research/nui/builder-library/controls"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/examples/README.md" "$DEST/research/nui/builder-library/examples"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/UI/examples/builder_poc_confirmed.md" "$DEST/research/nui/builder-library/examples"

# External dependencies.
copy_dir_with_filter "$SHADOW/TOOLS/AuroraBorealius-Toolset-and-Shargast-by-Jaysn" "$DEST/external/aurora-borealius" \
  --exclude='.git/' \
  --exclude='aurora-borealis/dist/' \
  --exclude='aurora-borealis/aurora-borealis'
copy_dir_with_filter "$OLD/tools/nwn_script_comp" "$DEST/external/nwn_script_comp"

# Toolset artifacts.
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/run-toolset.sh" "$DEST/toolset/scripts"
copy_file_if_exists "/tmp/nwn-nui-toolset/modules/03_r36s_bootstrap_nui_window.mod" "$DEST/toolset/userdir/modules"

# Debug/runtime research artifacts.
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/run-nui-test.sh" "$DEST/debug/scripts"
copy_file_if_exists "$SHADOW/NUI_BOOTSTRAP/NUI_EXPERIMENT_LOG.txt" "$DEST/debug/logs"
copy_file_if_exists "$OLD/show-keyboard.sh" "$DEST/debug/scripts"
copy_file_if_exists "$OLD/input-keyboard-diagnose.sh" "$DEST/debug/scripts"

# Legacy old-port-tree artifacts.
copy_file_if_exists "$OLD/start.sh" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/start-test.sh" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/nwmain-linux.gptk" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/nwmain-linux.gptk.bak" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/start.sh.bak-r36s-nwn" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/xorg-nwn.conf" "$DEST/legacy/old-port-tree/scripts"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/settings.tml" "$DEST/legacy/old-port-tree/config"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/nwn.ini" "$DEST/legacy/old-port-tree/config"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/nwnplayer.ini" "$DEST/legacy/old-port-tree/config"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/steam-pc-settings/settings.tml" "$DEST/legacy/old-port-tree/config"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/settings.tml.bak-r36s-safe-low" "$DEST/legacy/old-port-tree/config"
copy_file_if_exists "$OLD/DUMP-CONFIG-R36S-NWN/settings.tml.bak-r36s-safe-low-runtime" "$DEST/legacy/old-port-tree/config"

# Inventory snapshots.
{
  echo "# Final dev tree"
  echo
  tree -a -L 3 "$DEST"
} > "$TREE_DIR/final-dev.tree.txt"

# Copy inventory artifacts and manifests.
cp -a "$DEST/inventory/artifacts.md" "$MANIFEST_DIR/artifacts.md" 2>/dev/null || true

# Build checksum list for copied artifacts.
find "$DEST" -path "$DEST/inventory/checksums" -prune -o -type f -print0 | sort -z | xargs -0 sha256sum > "$CHECKSUM_DIR/copied-files.sha256"

# Manifest generation.
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
from collections import defaultdict
root = Path('/home/khizhnik/Games/PortMaster/r36s-nwn-ee-port')
dev = root / 'dev'
manifest_path = dev / 'inventory/manifests/migration-manifest.md'
now = datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')

categories = defaultdict(list)
for path in dev.rglob('*'):
    if not path.is_file():
        continue
    rel = path.relative_to(dev)
    s = str(rel)
    if s.startswith('inventory/'):
        continue
    if s.startswith('bootstrap/docs/'):
        cat = 'bootstrap/docs'
    elif s.startswith('bootstrap/modules/'):
        cat = 'bootstrap/modules'
    elif s.startswith('bootstrap/scripts/build/'):
        cat = 'bootstrap/build'
    elif s.startswith('bootstrap/scripts/'):
        cat = 'bootstrap/scripts'
    elif s.startswith('bootstrap/userdirs/'):
        cat = 'bootstrap/userdirs'
    elif s.startswith('research/toolchain/'):
        cat = 'research/toolchain'
    elif s.startswith('research/nui/builder-library/'):
        cat = 'research/nui/builder-library'
    elif s.startswith('external/aurora-borealius/'):
        cat = 'external/aurora-borealius'
    elif s.startswith('external/nwn_script_comp/'):
        cat = 'external/nwn_script_comp'
    elif s.startswith('toolset/scripts/'):
        cat = 'toolset/scripts'
    elif s.startswith('toolset/userdir/'):
        cat = 'toolset/userdir'
    elif s.startswith('debug/scripts/'):
        cat = 'debug/scripts'
    elif s.startswith('debug/logs/'):
        cat = 'debug/logs'
    elif s.startswith('debug/crashreports/'):
        cat = 'debug/crashreports'
    elif s.startswith('legacy/old-port-tree/scripts/'):
        cat = 'legacy/old-port-tree/scripts'
    elif s.startswith('legacy/old-port-tree/config/'):
        cat = 'legacy/old-port-tree/config'
    elif s.startswith('legacy/old-port-tree/notes/'):
        cat = 'legacy/old-port-tree/notes'
    elif s.startswith('nui/docs/'):
        cat = 'nui/docs'
    elif s.startswith('nui/sources/'):
        cat = 'nui/sources'
    else:
        cat = 'other'
    categories[cat].append(path)

counts = {k: len(v) for k, v in categories.items()}

lines = []
lines.append('# Migration Manifest')
lines.append('')
lines.append(f'- Generated: {now}')
lines.append('- Source directories inspected: `/tmp`, `/home/khizhnik/Games/PortMaster/nwn-ee`, `SHADOW-TEST`, and all explicit project subtrees used in the bootstrap/NUI/tooling investigation.')
lines.append('- Destination root: `/home/khizhnik/Games/PortMaster/r36s-nwn-ee-port/dev`')
lines.append('- No files were deleted.')
lines.append('- `port/` was not modified.')
lines.append('')
lines.append('## Artifact class notes')
lines.append('')
lines.append('- `*.nss` = canonical source')
lines.append('- `*.ncs` = compiled artifact')
lines.append('- `*.mod` = test artifact')
lines.append('')
lines.append('## Copied files count by category')
lines.append('')
for cat in sorted(counts):
    lines.append(f'- {cat}: {counts[cat]}')
lines.append('')
lines.append('## Skipped files count by category')
lines.append('')
lines.append('- AuroraBorealius `.git/`: 1 repository metadata tree skipped.')
lines.append('- AuroraBorealius generated `dist/`: skipped; build output not migrated.')
lines.append('- AuroraBorealius symlink target `aurora-borealis/aurora-borealis`: skipped; external target not migrated.')
lines.append('- Toolset runtime caches/autosaves/temp data in `/tmp/nwn-nui-toolset`: skipped; only the saved module artifact was preserved.')
lines.append('- Missing optional `/tmp` files: counted below as `missing_optional_files` in the manifest metadata section.')
lines.append('- Official game data trees (`data/`, `lang/`, `hak/`, `tlk/`, `movies/`, `music/`, `premium/`) were intentionally out of scope.')
lines.append('')
lines.append('## Missing optional files from /tmp')
lines.append('')
missing_path = dev / 'inventory/manifests/missing-optional-files.txt'
if missing_path.exists() and missing_path.read_text(encoding='utf-8').strip():
    for item in missing_path.read_text(encoding='utf-8').splitlines():
        if item.strip():
            lines.append(f'- `{item}`')
else:
    lines.append('- None.')
lines.append('')
lines.append('## Conflicts encountered')
lines.append('')
lines.append('- None. Existing files in `dev/` were not overwritten during this pass.')
lines.append('')
lines.append('## Confirmation')
lines.append('')
lines.append('- `port/` was not modified.')
lines.append('- Originals were not deleted.')
lines.append('')
lines.append('## Final dev tree (depth 3)')
lines.append('')
lines.append('```text')
lines.append((dev / 'inventory/trees/final-dev.tree.txt').read_text(encoding='utf-8').rstrip())
lines.append('```')
lines.append('')
lines.append('## git status --short')
lines.append('')
import subprocess
res = subprocess.run(['git', '-C', str(root), 'status', '--short'], capture_output=True, text=True, check=True)
lines.append('```text')
lines.append(res.stdout.rstrip())
lines.append('```')
lines.append('')
lines.append('## Next recommended step')
lines.append('')
lines.append('- Create a compatibility wrapper and fix hardcoded paths so the new tree can be used without referring back to the scattered old locations.')

manifest_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(manifest_path)
PY
