#!/usr/bin/env bash
# PostToolUse hook (Bash matcher).
# Detects errors / test failures / large diffs / success in tool output and
# writes a personality-flavored reaction to the active + called pet's
# .comment file. Cooldown: 30s per session.
#
# Adapted from claude-buddy/hooks/react.sh (MIT). Detection regexes preserved.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ACTIVE_SLUG=$(read_slug "$ACTIVE_FILE")
CALLED_SLUG=$(read_slug "$CALLED_FILE")

# Bail if no buddy is active and no called pet either.
[ -z "$ACTIVE_SLUG" ] && [ -z "$CALLED_SLUG" ] && exit 0

# Per-session cooldown stamp. Use TMUX pane if available, else default bucket.
SID="${TMUX_PANE#%}"; SID="${SID:-default}"
COOLDOWN_FILE="$PETS_DIR/.last_reaction.$SID"

COOLDOWN="${PET_REACT_COOLDOWN:-$REACT_COOLDOWN_DEFAULT}"
[[ "$COOLDOWN" =~ ^[0-9]+$ ]] || COOLDOWN=$REACT_COOLDOWN_DEFAULT

if [ "$COOLDOWN" -gt 0 ] && [ -f "$COOLDOWN_FILE" ]; then
    LAST=$(cat "$COOLDOWN_FILE" 2>/dev/null)
    NOW=$(date +%s)
    DIFF=$(( NOW - ${LAST:-0} ))
    [ "$DIFF" -lt "$COOLDOWN" ] && exit 0
fi

INPUT=$(cat)
RESULT=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null)
[ -z "$RESULT" ] && exit 0

# ── Detect event in tool output (regexes lifted from claude-buddy react.sh) ──
EVENT=""
if echo "$RESULT" | grep -qiE '\b[1-9][0-9]* (failed|failing)\b|tests? failed|^FAIL(ED)?|✗|✘'; then
    EVENT="test-fail"
elif echo "$RESULT" | grep -qiE '\berror:|\bexception\b|\btraceback\b|\bpanicked at\b|\bfatal:|exit code [1-9]'; then
    EVENT="error"
elif echo "$RESULT" | grep -qiE '^\+.*[0-9]+ insertions|[0-9]+ files? changed'; then
    LINES=$(echo "$RESULT" | grep -oE '[0-9]+ insertions' | grep -oE '[0-9]+' | head -1)
    [ "${LINES:-0}" -gt 80 ] && EVENT="large-diff"
elif echo "$RESULT" | grep -qiE '\b(all )?[0-9]+ tests? (passed|ok)\b|✓|✔|PASS(ED)?|\bSuccess\b|exit code 0|Build succeeded'; then
    EVENT="success"
fi

[ -z "$EVENT" ] && exit 0

# ── Pick + write reaction(s) ─────────────────────────────────────────────────
wrote_any=0

if [ -n "$ACTIVE_SLUG" ]; then
    PERSONALITY=$(get_pet_field "$ACTIVE_SLUG" "personality")
    pick_reaction "${PERSONALITY:-default}" "$EVENT"
    if [ -n "$REACTION" ]; then
        write_comment "$COMMENT_FILE" "$REACTION"
        wrote_any=1
    fi
fi

if [ -n "$CALLED_SLUG" ] && [ "$CALLED_SLUG" != "$ACTIVE_SLUG" ]; then
    PERSONALITY=$(get_pet_field "$CALLED_SLUG" "personality")
    pick_reaction "${PERSONALITY:-default}" "$EVENT"
    if [ -n "$REACTION" ]; then
        write_comment "$CALLED_COMMENT_FILE" "$REACTION"
        wrote_any=1
    fi
fi

# Stamp cooldown only if we actually wrote a reaction.
[ "$wrote_any" -eq 1 ] && date +%s > "$COOLDOWN_FILE"

exit 0
