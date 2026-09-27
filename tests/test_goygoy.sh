#!/usr/bin/env bash
# goygoy test suite. Run from the repo root: ./tests/test_goygoy.sh
# Plain bash, compatible with macOS /bin/bash 3.2. Every case runs against a
# throwaway copy of the plugin in a directory whose name contains a space.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIG_PATH="$PATH"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

# check <name> <command...> : passes when the command exits 0
check() {
  local name="$1"; shift
  if "$@"; then ok "$name"; else fail "$name"; fi
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }

# Fresh sandbox per case: plugin copy, fake players first on PATH, isolated config dir.
setup() {
  T="$(mktemp -d)"
  P="$T/my plugin"
  mkdir -p "$P/scripts" "$P/sounds" "$T/bin" "$T/config"
  cp -p "$ROOT"/scripts/*.sh "$P/scripts/"
  export LOG="$T/players.log"
  : > "$LOG"
  for player in afplay say; do
    cat > "$T/bin/$player" <<'EOF'
#!/bin/bash
name="$(basename "$0")"
echo "$name $*" >> "$LOG"
if [ "$name" = say ] && [ "${FAKE_NO_YELDA:-}" = 1 ] && [ "$1" = -v ]; then exit 1; fi
sleep "${FAKE_SLEEP:-0}"
EOF
    chmod +x "$T/bin/$player"
  done
  export PATH="$T/bin:$ORIG_PATH"
  export XDG_CONFIG_HOME="$T/config"
  unset GOYGOY_MODE FAKE_SLEEP FAKE_NO_YELDA
}

teardown() { rm -rf "$T"; }

# mode <args...> : run mode.sh the way the slash commands do (direct exec)
mode() { "$P/scripts/mode.sh" "$@"; }

SOUND_LINE="goygoy: konuşuyor 🔊 (sound)"
TEXT_LINE="goygoy: sustu 🤫 (text — Claude söyleyecek)"

# --- mode.sh ------------------------------------------------------------------

setup
check "mode: defaults to sound when nothing is saved" \
  test "$(mode status)" = "$SOUND_LINE"
check "mode: no argument means status" \
  test "$(mode)" = "$SOUND_LINE"
teardown

setup
out="$(mode text)"
check "mode: 'text' prints the resulting mode" test "$out" = "$TEXT_LINE"
check "mode: 'text' writes the mode file" \
  test "$(cat "$XDG_CONFIG_HOME/goygoy/mode")" = text
check "mode: status reports the saved text mode" test "$(mode status)" = "$TEXT_LINE"
mode sound >/dev/null
check "mode: 'sound' switches back" test "$(mode status)" = "$SOUND_LINE"
teardown

setup
mode text >/dev/null
check "mode: GOYGOY_MODE overrides the saved file" \
  test "$(GOYGOY_MODE=sound mode status | head -1)" = "$SOUND_LINE"
teardown

# Review focus: an exported GOYGOY_MODE must not let /goygoy:sus claim it muted
setup
out="$(GOYGOY_MODE=sound mode text)"
check "mode: reports the effective mode when an override is set" \
  test "$(head -1 <<<"$out")" = "$SOUND_LINE"
check "mode: names the override" grep -qF 'GOYGOY_MODE=sound' <<<"$out"
teardown

# Review focus: hand-edited mode file with whitespace / CRLF / garbage
setup
mkdir -p "$XDG_CONFIG_HOME/goygoy"
printf ' text\r\n' > "$XDG_CONFIG_HOME/goygoy/mode"
check "mode: tolerates whitespace and CRLF in the mode file" \
  test "$(mode status)" = "$TEXT_LINE"
printf 'banana\n' > "$XDG_CONFIG_HOME/goygoy/mode"
check "mode: unknown file content falls back to sound" \
  test "$(mode status)" = "$SOUND_LINE"
teardown

setup
mode banana >/dev/null 2>&1
code=$?
check "mode: rejects unknown arguments with exit 2" test "$code" -eq 2
teardown

# --- summary ------------------------------------------------------------------
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
