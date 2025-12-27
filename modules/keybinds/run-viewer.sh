#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[+] Generating keybinds.json..."

cd "$SCRIPT_DIR/scripts"

python expand.py \
  | python extract_binds.py \
  | python dedupe_binds.py \
  | python pretty_print_binds.py \
  > ../keybinds.json

cd "$SCRIPT_DIR"

echo "[+] Launching KeybindsViewer.qml"

QML_XHR_ALLOW_FILE_READ=1 qmlscene KeybindsViewer.qml
