#!/usr/bin/env bash
# Hook entry point: goygoy.sh <HookEventName>   (hook JSON arrives on stdin)
# sound mode: plays the meme clip, or speaks the phrase, in the background; prints nothing.
# text mode:  prints hook JSON telling Claude to open its reply with the phrase.
# A meme must never break Claude Code, so every failure path exits 0 silently.

exec 2>/dev/null
cat >/dev/null # drain the hook payload; unused in v1

# Headless runs (claude -p, Agent SDK) are scripts: stay out of their output and keep quiet.
case "${CLAUDE_CODE_ENTRYPOINT:-}" in
  sdk-*) [ "${GOYGOY_HEADLESS:-}" = 1 ] || exit 0 ;;
esac

event="${1:-}"
root="$(cd "$(dirname "$0")/.." && pwd)" || exit 0
source "$root/scripts/lib.sh" || exit 0
memes="$root/memes.json"

command -v jq >/dev/null || exit 0
count="$(jq --arg e "$event" '.[$e] | if type == "array" then length else 0 end' "$memes")" || exit 0
case "$count" in
  ''|0|*[!0-9]*) exit 0 ;;
esac

meme="$(jq -c --arg e "$event" --argjson i "$((RANDOM % count))" '.[$e][$i]' "$memes")" || exit 0
phrase="$(jq -r '.phrase // empty' <<<"$meme")"
sound="$(jq -r '.sound // empty' <<<"$meme")"
[ -n "$phrase" ] || exit 0

if [ "$(goygoy_mode)" = text ]; then
  jq -cn --arg e "$event" --arg p "$phrase" '{
    hookSpecificOutput: {
      hookEventName: $e,
      additionalContext: ("Start your reply with exactly \"" + $p + "\" on its own line, then continue normally.")
    }
  }'
  exit 0
fi

# Players must not inherit our stdout: Claude Code waits for that pipe to close.
clip="$root/sounds/$sound"
if [ -n "$sound" ] && [ -f "$clip" ]; then
  afplay "$clip" >/dev/null 2>&1 &
else
  { say -v Yelda "$phrase" || say "$phrase"; } >/dev/null 2>&1 &
fi
exit 0
