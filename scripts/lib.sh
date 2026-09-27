# Shared helpers for goygoy scripts. Source this file; don't execute it.
# Must stay compatible with macOS /bin/bash 3.2.

# Path of the saved mode file.
goygoy_mode_file() {
  printf '%s/goygoy/mode\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Saved mode ("sound" or "text"); prints nothing if unset or unrecognized.
goygoy_saved_mode() {
  local file saved
  file="$(goygoy_mode_file)"
  [ -r "$file" ] || return 0
  saved="$(tr -d '[:space:]' < "$file")"
  case "$saved" in
    sound|text) printf '%s\n' "$saved" ;;
  esac
}

# Effective mode: $GOYGOY_MODE if valid, else the saved mode, else "sound".
goygoy_mode() {
  case "${GOYGOY_MODE:-}" in
    sound|text) printf '%s\n' "$GOYGOY_MODE"; return 0 ;;
  esac
  local saved
  saved="$(goygoy_saved_mode)"
  printf '%s\n' "${saved:-sound}"
}
