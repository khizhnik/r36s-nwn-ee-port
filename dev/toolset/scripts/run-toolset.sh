#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLSET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

STEAM_NWN_DIR="${STEAM_NWN_DIR:-$HOME/.steam/debian-installation/steamapps/common/Neverwinter Nights}"
TOOLSET_DIR="$STEAM_NWN_DIR/bin/win32"
TOOLSET_USERDIR="${TOOLSET_USERDIR:-/tmp/nwn-nui-toolset}"

mkdir -p "$TOOLSET_USERDIR"
cd "$TOOLSET_DIR"
wine ./nwtoolset.exe -userdirectory "$TOOLSET_USERDIR"
