#!/usr/bin/env bash
# Stop hook.
# Single source of per-turn pet voice. On every turn:
#   1. Bumps the active pet's xp.
#   2. If the assistant message contains an explicit <!-- pet: ... --> or
#      <!-- <slug>: ... --> tag, writes it verbatim (skill override path —
#      lets a skill invocation speak for the pet without Haiku overriding).
#   3. Otherwise fires a backgrounded Haiku 4.5 heckle using the last
#      user+assistant exchange from the transcript. The pet reads what
#      actually happened and reacts in character.
#
# Guard: PET_NO_HOOK=1 short-circuits, so the nested `claude -p` session's
# own Stop hook doesn't recurse or double-bump xp.

set -uo pipefail

[ -n "${PET_NO_HOOK:-}" ] && exit 0

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ACTIVE_SLUG=$(read_slug "$ACTIVE_FILE")
CALLED_SLUG=$(read_slug "$CALLED_FILE")

# Per-turn xp bump for the active pet.
[ -n "$ACTIVE_SLUG" ] && bump_xp "$ACTIVE_SLUG"

# Passive kibble drop — ~15% chance per turn (task completion reward).
if [ -n "$ACTIVE_SLUG" ] && [ $(( $(date +%s) % 100 )) -lt 15 ]; then
    add_item "kibble" 1
fi

# ── Decrement status effects (hallucinating/hexed) ──────────────────────────
decrement_status() {
    local slug="$1" comment_path="$2"
    [ -z "$slug" ] && return
    local file="$PETS_DIR/$slug.md"
    [ -f "$file" ] || return
    local status
    status=$(get_pet_field "$slug" "status" 2>/dev/null)
    [ -z "$status" ] && return
    local effect n
    effect="${status%%:*}"
    n="${status##*:}"
    [[ "$n" =~ ^[0-9]+$ ]] || return
    n=$((n - 1))
    local tmp
    tmp=$(mktemp)
    if [ "$n" -le 0 ]; then
        awk '/^status:/ { next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
        case "$effect" in
            hallucinating)
                write_comment "$comment_path" "man... man that was something, where did the afternoon go, everything looks so... flat now"
                ;;
            hexed)
                write_comment "$comment_path" "the hex has settled in permanently... or so they say"
                ;;
            stoned)
                write_comment "$comment_path" "man... that was a whole thing, you know? like, what even is a function"
                ;;
        esac
    else
        awk -v eff="$effect" -v cnt="$n" '
            /^status:/ { print "status: " eff ":" cnt; next } { print }
        ' "$file" > "$tmp" && mv "$tmp" "$file"
    fi
}

[ -n "$ACTIVE_SLUG" ] && decrement_status "$ACTIVE_SLUG" "$COMMENT_FILE"
[ -n "$CALLED_SLUG" ] && [ "$CALLED_SLUG" != "$ACTIVE_SLUG" ] && decrement_status "$CALLED_SLUG" "$CALLED_COMMENT_FILE"

# Sweep all pets for status effects not covered by active/called slots.
# Prevents trips from freezing when the frog is neither active nor called.
for _pet_file in "$PETS_DIR"/*.md; do
    [[ "$_pet_file" == *memory* ]] && continue
    [[ "$_pet_file" == *inventory* ]] && continue
    _slug=$(basename "$_pet_file" .md)
    [ "$_slug" = "$ACTIVE_SLUG" ] && continue
    [ "$_slug" = "$CALLED_SLUG" ] && continue
    _status=$(get_pet_field "$_slug" "status" 2>/dev/null)
    [ -z "$_status" ] && continue
    decrement_status "$_slug" /dev/null
done

INPUT=$(cat)
ASSISTANT_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

# ── Dismiss alien on new session ────────────────────────────────────────────
ALIEN_SESSION_FILE="$PETS_DIR/.alien-session"
if [ "$(read_slug "$CALLED_FILE")" = "alien" ] && [ -n "$TRANSCRIPT" ]; then
    stored=""
    [ -f "$ALIEN_SESSION_FILE" ] && stored=$(cat "$ALIEN_SESSION_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$stored" ] && [ "$stored" != "$TRANSCRIPT" ]; then
        echo "" > "$CALLED_FILE"
        echo "" > "$CALLED_COMMENT_FILE"
        rm -f "$ALIEN_SESSION_FILE"
        CALLED_SLUG=""
    else
        echo "$TRANSCRIPT" > "$ALIEN_SESSION_FILE"
    fi
fi

# ── Extract last real user message from the transcript ─────────────────────
# Filter out tool_result-only user entries (those are injected, not typed).
USER_MSG=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    USER_MSG=$(jq -rs '
        map(
            select(.type == "user")
            | select(
                (.message.content | type) == "string"
                or (
                    (.message.content | type) == "array"
                    and ([.message.content[] | .type] | index("tool_result") | not)
                )
            )
            | .message.content
            | if type == "string" then .
              else ([.[] | select(.type == "text") | .text] | join(" "))
              end
        )
        | map(select(length > 0))
        | last // ""
    ' "$TRANSCRIPT" 2>/dev/null)
fi

# ── Route explicit HTML-comment tags (skill override path) ─────────────────
# Returns 1 if active/called slot was written, so we know to skip Haiku.
active_written=0
called_written=0
if [ -n "$ASSISTANT_MSG" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        KEY=$(echo "$line" | sed -n 's/^\([^:]*\):.*$/\1/p')
        TEXT=$(echo "$line" | sed -n 's/^[^:]*:[ ]*\(.*\)$/\1/p')
        [ -z "$TEXT" ] && continue
        case "$KEY" in
            pet)
                [ -n "$ACTIVE_SLUG" ] && { write_comment "$COMMENT_FILE" "$TEXT"; active_written=1; }
                ;;
            "$ACTIVE_SLUG")
                write_comment "$COMMENT_FILE" "$TEXT"; active_written=1
                ;;
            "$CALLED_SLUG")
                write_comment "$CALLED_COMMENT_FILE" "$TEXT"; called_written=1
                ;;
        esac
    done < <(echo "$ASSISTANT_MSG" | sed -n 's/.*<!-- *\([a-zA-Z0-9_-]\{1,\}\): *\([^>]*[^ >]\) *-->.*/\1: \2/p')
fi

# ── Consume skill-spoke markers (skill already wrote for the pet) ──────────
if [ -f "$SKILL_SPOKE_ACTIVE" ]; then
    rm -f "$SKILL_SPOKE_ACTIVE"
    active_written=1
fi
if [ -f "$SKILL_SPOKE_CALLED" ]; then
    rm -f "$SKILL_SPOKE_CALLED"
    called_written=1
fi

# ── Fire Haiku heckle for any slot that wasn't explicitly written ──────────
if [ -n "$ACTIVE_SLUG" ] && [ "$active_written" -eq 0 ]; then
    gen_heckle "$ACTIVE_SLUG" "$COMMENT_FILE" "$USER_MSG" "$ASSISTANT_MSG"
fi
if [ -n "$CALLED_SLUG" ] && [ "$CALLED_SLUG" != "$ACTIVE_SLUG" ] && [ "$called_written" -eq 0 ]; then
    gen_heckle "$CALLED_SLUG" "$CALLED_COMMENT_FILE" "$USER_MSG" "$ASSISTANT_MSG"
fi

exit 0
