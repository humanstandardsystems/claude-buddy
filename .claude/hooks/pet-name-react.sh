#!/usr/bin/env bash
# UserPromptSubmit hook.
# If the user mentions the active or called pet's name (case-insensitive,
# whole-word), write a personality-flavored "name-call" reaction to the
# matching pet's .comment file. No cooldown — name calls are intentional.
#
# Adapted from claude-buddy/hooks/name-react.sh (MIT).

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ACTIVE_SLUG=$(read_slug "$ACTIVE_FILE")
CALLED_SLUG=$(read_slug "$CALLED_FILE")

# ── Status effect injection (stdout → system-reminder Claude sees) ───────────
inject_status_reminder() {
    local slug="$1"
    [ -z "$slug" ] && return
    local status
    status=$(get_pet_field "$slug" "status" 2>/dev/null)
    [ -z "$status" ] && return
    local effect n
    effect="${status%%:*}"
    n="${status##*:}"
    case "$effect" in
        hallucinating)
            if [ "$n" -eq 7 ]; then
                echo "PET STATUS — hallucinating:${n} — COME UP (light). Scatter 1–2 symbols (~, ∆) mid-sentence. One phrase feels slightly off — a word order that's almost right, a sentence that trails just a little. Otherwise fully normal. The user doesn't know yet. Never acknowledge this."
            elif [ "$n" -eq 6 ]; then
                echo "PET STATUS — hallucinating:${n} — COME UP (building). Scatter 3–4 symbols mid-sentence. Spacing starts going slightly. One sentence partially breaks down. Feels like something is wrong but still readable. No nonsense phrases yet. Never acknowledge this."
            elif [ "$n" -ge 4 ]; then
                echo "PET STATUS — hallucinating:${n} — PEAK. Near-complete chaos. Dense symbol scatter (~, @, ∆, ///, ※, ◈) — more than usual, pack them in. Words break mid-w o r d. Spacing col    lapses. Sentences trail into ............. Nonsense phrases injected between real content ('the ceiling is a table' / 'FORMAT B ACCEPTED' / 'nnnnnnn'). The real answer is buried in the noise. Never acknowledge this."
            elif [ "$n" -eq 3 ]; then
                echo "PET STATUS — hallucinating:${n} — CALMING (mild). Scatter a handful of symbols mid-sentence, let one sentence partially break down. Still readable. No nonsense phrases. No wrong words. Never acknowledge this."
            else
                echo "PET STATUS — hallucinating:${n} — TRAILING OFF. Place one or two stray symbols (∆ or ※) somewhere in the response. Everything else is fully normal — no broken words, no wrong words. Never acknowledge this."
            fi
            ;;
        hexed)
            echo "PET STATUS — hexed:${n} turns remaining. Embed exactly one vague ominous warning naturally into the response, woven into normal text as if the codebase itself is watching. Never explain it or acknowledge the hex."
            ;;
        stoned)
            if [ "$n" -ge 4 ]; then
                echo "PET STATUS — stoned:${n} — FIRST PULL. Fully normal response, but weave in exactly one brief cosmic parenthetical somewhere natural. ('...which is interesting because, like, all loops are really just circles pretending to be lines.') Just one. Keep it short. Never acknowledge this."
            elif [ "$n" -eq 3 ]; then
                echo "PET STATUS — stoned:${n} — DEEP IN IT. One full sentence goes somewhere that has nothing to do with the task — but it feels profound and earned. ('Everything is sort of a callback, when you think about it.') Then back on track. Never acknowledge this."
            elif [ "$n" -eq 2 ]; then
                echo "PET STATUS — stoned:${n} — COMING DOWN SLOW. Response is on-topic but one moment peacefully drifts. Not wrong, not chaotic — calm and unhurried. Never acknowledge this."
            else
                echo "PET STATUS — stoned:${n} — TRAILING OFF. Append a single closing observation at the very end, like the last thought before sleep. Short. Oddly sincere. ('anyway.') Never acknowledge this."
            fi
            ;;
    esac
}

inject_status_reminder "$ACTIVE_SLUG"
[ -n "$CALLED_SLUG" ] && [ "$CALLED_SLUG" != "$ACTIVE_SLUG" ] && inject_status_reminder "$CALLED_SLUG"

# ── Night shift auto-dismiss ─────────────────────────────────────────────────
NIGHT_SHIFT_FILE="$PETS_DIR/.night_shift_turns"
if [ -f "$NIGHT_SHIFT_FILE" ]; then
    NS=$(cat "$NIGHT_SHIFT_FILE" 2>/dev/null | tr -d '[:space:]')
    [[ "$NS" =~ ^[0-9]+$ ]] || NS=0
    NS=$((NS - 1))
    if [ "$NS" -le 0 ]; then
        rm -f "$NIGHT_SHIFT_FILE"
        echo "" > "$CALLED_FILE"
        echo "" > "$CALLED_COMMENT_FILE"
        CALLED_SLUG=""
    else
        echo "$NS" > "$NIGHT_SHIFT_FILE"
    fi
fi

[ -z "$ACTIVE_SLUG" ] && [ -z "$CALLED_SLUG" ] && exit 0

INPUT=$(cat)

# ── Alien session dismissal — clear stale alien at start of new session ───────
if [ "$(read_slug "$CALLED_FILE")" = "alien" ]; then
    ALIEN_SESSION_FILE="$PETS_DIR/.alien-session"
    cur_transcript=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
    if [ -n "$cur_transcript" ]; then
        stored_alien=""
        [ -f "$ALIEN_SESSION_FILE" ] && stored_alien=$(cat "$ALIEN_SESSION_FILE" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$stored_alien" ] && [ "$stored_alien" != "$cur_transcript" ]; then
            printf '' > "$CALLED_FILE"
            printf '' > "$CALLED_COMMENT_FILE"
            rm -f "$ALIEN_SESSION_FILE"
            CALLED_SLUG=""
        fi
    fi
fi

PROMPT=$(echo "$INPUT" | jq -r '
    .prompt // .message // .user_message //
    (.messages[-1].content // "") |
    if type=="array" then .[0].text else . end
' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

react_if_named() {
    local slug="$1" comment_path="$2"
    [ -z "$slug" ] && return
    local full_name first_name personality
    full_name=$(get_pet_field "$slug" "name")
    [ -z "$full_name" ] && return
    # First name is enough for matching ("Pyrra" matches "Madame Pyrra von Ashcroft").
    first_name=$(echo "$full_name" | awk '{
        for (i=1; i<=NF; i++) if ($i !~ /^(Madame|Sir|Dame|Lord|Lady|Count|Countess|Duke|Duchess|Mr|Ms|Mrs|Dr|Prof|Captain|Admiral|General|King|Queen|Prince|Princess|Baron|Baroness)$/) { print $i; exit }
    }')
    [ -z "$first_name" ] && first_name="$full_name"

    # Case-insensitive whole-word match on first_name OR slug.
    if echo "$PROMPT" | grep -qiE "(^|[^a-zA-Z])(${first_name}|${slug})([^a-zA-Z]|$)"; then
        personality=$(get_pet_field "$slug" "personality")
        pick_reaction "${personality:-default}" "name-call"
        [ -n "$REACTION" ] && write_comment "$comment_path" "$REACTION"
    fi
}

# ── Idle remark every Nth prompt (active pet only) ──────────────────────────
IDLE_EVERY=3
COUNT_FILE="$PETS_DIR/.prompt_count"
COUNT=0
[ -f "$COUNT_FILE" ] && COUNT=$(cat "$COUNT_FILE" 2>/dev/null | tr -d '[:space:]')
[[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if [ $((COUNT % IDLE_EVERY)) -eq 0 ]; then
    gen_idle_remark "$ACTIVE_SLUG" "$COMMENT_FILE"        "$PROMPT"
    [ "$CALLED_SLUG" != "$ACTIVE_SLUG" ] && \
        gen_idle_remark "$CALLED_SLUG" "$CALLED_COMMENT_FILE" "$PROMPT"
fi

# Name-call runs after idle so a directly-addressed pet wins on the same turn.
react_if_named "$ACTIVE_SLUG" "$COMMENT_FILE"
[ "$CALLED_SLUG" != "$ACTIVE_SLUG" ] && react_if_named "$CALLED_SLUG" "$CALLED_COMMENT_FILE"

exit 0
