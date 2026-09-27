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

# --- goygoy.sh (hook engine) --------------------------------------------------

PHRASE='Başımla beraber abi! 🫡'
FIXTURE='{"UserPromptSubmit":[{"phrase":"Başımla beraber abi! 🫡","sound":"clip.mp3"}]}'

# memes <json> : write the sandbox registry
memes() { printf '%s\n' "$1" > "$P/memes.json"; }

# hook <event> : run goygoy.sh exactly like hooks.json does; sets OUT, CODE, ELAPSED_MS
hook() {
  local start
  start="$(now_ms)"
  OUT="$(printf '{"hook_event_name":"%s","prompt":"refactor the login page"}' "$1" \
    | bash "$P/scripts/goygoy.sh" "$1")"
  CODE=$?
  ELAPSED_MS=$(( $(now_ms) - start ))
}

# wait_for_log <lines> : players run in the background; wait up to 2s for their log
wait_for_log() {
  local tries=0
  while [ "$(wc -l < "$LOG" | tr -d ' ')" -lt "$1" ] && [ "$tries" -lt 20 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
}

# json_true <jq args...> : jq -e without printing the result
json_true() { jq -e "$@" >/dev/null; }

setup
memes "$FIXTURE"
: > "$P/sounds/clip.mp3"
hook UserPromptSubmit
wait_for_log 1
check "sound: plays the clip with afplay when it exists" \
  grep -qxF "afplay $P/sounds/clip.mp3" "$LOG"
check "sound: prints nothing" test -z "$OUT"
check "sound: exits 0" test "$CODE" -eq 0
teardown

setup
memes "$FIXTURE"
hook UserPromptSubmit
wait_for_log 1
check "sound: clip missing -> speaks the phrase with Yelda" \
  grep -qxF "say -v Yelda $PHRASE" "$LOG"
check "sound: clip missing -> prints nothing" test -z "$OUT"
teardown

setup
memes '{"UserPromptSubmit":[{"phrase":"Başımla beraber abi! 🫡"}]}'
hook UserPromptSubmit
wait_for_log 1
check "sound: meme without a sound field -> speaks the phrase" \
  grep -qxF "say -v Yelda $PHRASE" "$LOG"
teardown

# Review focus: Yelda voice missing (other Macs) -> default voice, not silence
setup
memes "$FIXTURE"
export FAKE_NO_YELDA=1
hook UserPromptSubmit
wait_for_log 2
check "sound: falls back to the default voice when Yelda is missing" \
  grep -qxF "say $PHRASE" "$LOG"
teardown

setup
memes "$FIXTURE"
: > "$P/sounds/clip.mp3"
export FAKE_SLEEP=3
hook UserPromptSubmit
check "sound: hook returns in <1s while a 3s clip plays (took ${ELAPSED_MS}ms)" \
  test "$ELAPSED_MS" -lt 1000
teardown

setup
memes "$FIXTURE"
mode text >/dev/null
hook UserPromptSubmit
check "text: prints hook JSON for the event" \
  json_true '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' <<<"$OUT"
check "text: additionalContext is the exact instruction" \
  json_true --arg p "$PHRASE" \
    '.hookSpecificOutput.additionalContext == ("Start your reply with exactly \"" + $p + "\" on its own line, then continue normally.")' \
    <<<"$OUT"
check "text: exits 0" test "$CODE" -eq 0
sleep 0.3
check "text: plays no sound" test ! -s "$LOG"
teardown

# Review focus: quotes, backslashes, Turkish letters and emoji survive into the JSON
setup
memes '{"UserPromptSubmit":[{"phrase":"Abi \"dur\" \\ ğüşıöç İ 🫡"}]}'
mode text >/dev/null
hook UserPromptSubmit
check "text: phrase with quotes/backslash/Turkish chars stays intact" \
  json_true --arg p 'Abi "dur" \ ğüşıöç İ 🫡' \
    '.hookSpecificOutput.additionalContext | contains($p)' <<<"$OUT"
teardown

setup
memes '{"UserPromptSubmit":[{"phrase":"bir"},{"phrase":"iki"}]}'
mode text >/dev/null
seen=""
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  hook UserPromptSubmit
  seen="$seen $(jq -r '.hookSpecificOutput.additionalContext' <<<"$OUT")"
done
check "several memes: sometimes picks the first" grep -qF '"bir"' <<<"$seen"
check "several memes: sometimes picks the second" grep -qF '"iki"' <<<"$seen"
teardown

setup
memes "$FIXTURE"
hook Stop
sleep 0.3
check "event without memes: exits 0" test "$CODE" -eq 0
check "event without memes: prints nothing" test -z "$OUT"
check "event without memes: plays nothing" test ! -s "$LOG"
teardown

setup
memes '{"UserPromptSubmit": [ {"phrase": '
hook UserPromptSubmit
sleep 0.3
check "malformed memes.json: exits 0" test "$CODE" -eq 0
check "malformed memes.json: prints nothing" test -z "$OUT"
check "malformed memes.json: plays nothing" test ! -s "$LOG"
teardown

setup
hook UserPromptSubmit
check "missing memes.json: exits 0" test "$CODE" -eq 0
check "missing memes.json: prints nothing" test -z "$OUT"
teardown

check "shipped memes.json: UserPromptSubmit has the başımla meme" \
  json_true --arg p "$PHRASE" \
    '.UserPromptSubmit | any(.phrase == $p and .sound == "basimla-beraber-abi.mp3")' \
    "$ROOT/memes.json"

# --- summary ------------------------------------------------------------------
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
