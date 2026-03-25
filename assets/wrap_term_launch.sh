#!/usr/bin/env sh

cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt 2>/dev/null

exec "$@"
