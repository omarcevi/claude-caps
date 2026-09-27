#!/usr/bin/env bash
# Usage: mode.sh [sound|text|status]
# Saves the goygoy mode and prints the effective one. Run by /goygoy:sus and /goygoy:konus.

source "$(dirname "$0")/lib.sh"

case "${1:-status}" in
  sound|text)
    file="$(goygoy_mode_file)"
    if ! { mkdir -p "$(dirname "$file")" && printf '%s\n' "$1" > "$file"; } 2>/dev/null; then
      echo "goygoy: could not save the mode to $file" >&2
      exit 1
    fi
    ;;
  status) ;;
  *)
    echo "usage: mode.sh [sound|text|status]" >&2
    exit 2
    ;;
esac

case "$(goygoy_mode)" in
  text) echo "goygoy: sustu 🤫 (text — Claude söyleyecek)" ;;
  *)    echo "goygoy: konuşuyor 🔊 (sound)" ;;
esac

case "${GOYGOY_MODE:-}" in
  sound|text) echo "  (GOYGOY_MODE=$GOYGOY_MODE is set in your environment and overrides the saved setting)" ;;
esac
