#!/usr/bin/env bash
# Copies files into the booted iOS Simulator's Files app ("On My iPhone"),
# so they can be picked from MD Viewer's 開啟檔案 or shared to it.
#
#   tool/sim_add_files.sh README.md docs/*.md
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $0 <file>..." >&2
  exit 1
fi

storage=$(xcrun simctl get_app_container booted com.apple.DocumentsApp groups 2>/dev/null \
  | awk -F'\t' '/FileProvider.LocalStorage/ {print $2}')
if [ -z "$storage" ]; then
  echo "No booted simulator found (start one in Simulator.app first)." >&2
  exit 1
fi

dest="$storage/File Provider Storage"
mkdir -p "$dest"
cp "$@" "$dest/"
echo "Copied $# file(s) to 檔案 App › 我的 iPhone"
