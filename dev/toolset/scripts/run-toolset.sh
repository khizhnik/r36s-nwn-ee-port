#!/usr/bin/env bash
set -e

GAME_DIR="/home/khizhnik/.steam/debian-installation/steamapps/common/Neverwinter Nights"
TOOLSET_DIR="$GAME_DIR/bin/win32"
USERDIR="/tmp/nwn-nui-toolset"

mkdir -p "$USERDIR"
cd "$TOOLSET_DIR"
wine ./nwtoolset.exe -userdirectory "$USERDIR"
