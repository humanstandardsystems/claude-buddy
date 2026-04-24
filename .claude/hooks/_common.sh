#!/usr/bin/env bash
# Shared helpers for pet hooks. Source this file from individual hooks.
# Lessons applied:
#   16 — verbatim writes only, no compression
#   17 — never truncate comment length
#   19 — never clear .active

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PETS_DIR="$REPO_ROOT/Pets"
ACTIVE_FILE="$PETS_DIR/.active"
CALLED_FILE="$PETS_DIR/.called"
COMMENT_FILE="$PETS_DIR/.comment"
CALLED_COMMENT_FILE="$PETS_DIR/.called-comment"
SKILL_SPOKE_ACTIVE="$PETS_DIR/.skill_spoke_active"
SKILL_SPOKE_CALLED="$PETS_DIR/.skill_spoke_called"

# Default reaction cooldown (seconds). PostToolUse only.
REACT_COOLDOWN_DEFAULT=30

# ── Read a top-level YAML frontmatter field from a pet file ──────────────────
# Usage: get_pet_field <slug> <field>
get_pet_field() {
    local slug="$1" field="$2"
    local file="$PETS_DIR/$slug.md"
    [ -f "$file" ] || return 1
    awk -v f="$field" '
        /^---/ { fm = !fm; next }
        fm && $1 == f":" { sub(/^[^:]+:[ \t]*/, ""); print; exit }
    ' "$file"
}

# ── Resolve a slug from a state file (.active or .called) ────────────────────
# Returns empty string if file missing/empty.
read_slug() {
    local file="$1"
    [ -f "$file" ] || { echo ""; return; }
    head -n1 "$file" | tr -d '[:space:]'
}

# ── Write text verbatim to a comment file (lesson 16) ────────────────────────
# Usage: write_comment <path> <text>
write_comment() {
    local path="$1" text="$2"
    [ -z "$text" ] && return
    # printf to preserve text exactly; no trailing newline (statusline strips ws)
    printf '%s' "$text" > "$path"
}

# ── Bump a pet's xp by +1, recompute level/stage per buddy.md curve ─────────
# Usage: bump_xp <slug>
# XP curve: tier costs [3,8,15,25,40], 5 levels per tier, 4 stages, 455 xp/stage.
bump_xp() {
    local slug="$1"
    local file="$PETS_DIR/$slug.md"
    [ -f "$file" ] || return
    local current_xp
    current_xp=$(get_pet_field "$slug" "xp")
    [[ "$current_xp" =~ ^[0-9]+$ ]] || current_xp=0
    local new_xp=$((current_xp + 1))

    # Derive level/stage in awk to avoid spawning python.
    local derived
    derived=$(awk -v xp="$new_xp" 'BEGIN {
        split("3 8 15 25 40", costs, " ")
        levels_per_tier = 5
        levels_per_stage = levels_per_tier * 5
        xp_per_stage = 0
        for (i = 1; i <= 5; i++) xp_per_stage += costs[i] * levels_per_tier
        stages[0] = "baby"; stages[1] = "adolescent"; stages[2] = "adult"; stages[3] = "legendary"

        stage_idx = int(xp / xp_per_stage)
        if (stage_idx > 3) stage_idx = 3
        stage_xp = xp - stage_idx * xp_per_stage
        if (stage_idx == 3 && stage_xp >= xp_per_stage) stage_xp = xp_per_stage - 1

        remaining = stage_xp
        level_in_stage = 1
        for (t = 1; t <= 5; t++) {
            for (l = 1; l <= levels_per_tier; l++) {
                if (remaining < costs[t]) {
                    print stage_idx * levels_per_stage + level_in_stage, stages[stage_idx]
                    exit
                }
                remaining -= costs[t]
                level_in_stage++
            }
        }
        print (stage_idx + 1) * levels_per_stage, stages[stage_idx]
    }')
    local new_level new_stage
    new_level=$(echo "$derived" | awk '{print $1}')
    new_stage=$(echo "$derived" | awk '{print $2}')

    # Rewrite frontmatter fields in place. Only the three fields we care about.
    local tmp
    tmp=$(mktemp)
    awk -v xp="$new_xp" -v lvl="$new_level" -v stg="$new_stage" '
        BEGIN { fm = 0 }
        /^---$/ { fm = !fm; print; next }
        fm && /^xp:/    { print "xp: " xp; next }
        fm && /^level:/ { print "level: " lvl; next }
        fm && /^stage:/ { print "stage: " stg; next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── Generate a per-turn in-character heckle via Haiku 4.5 ──────────────────
# Backgrounds a `claude -p` call with the full user+assistant exchange so the
# pet can actually READ what happened and react with substance (persistent
# heckling, Haiku-powered, no pools). Caller does not block.
# PET_NO_HOOK=1 is exported into the subshell so the nested `claude -p`
# session's Stop hook short-circuits without bumping XP or recursing.
# Usage: gen_heckle <slug> <comment_path> <user_msg> <assistant_msg>
gen_heckle() {
    local slug="$1" comment_path="$2" user_msg="$3" assistant_msg="$4"
    [ -z "$slug" ] && return
    local name personality species
    name=$(get_pet_field "$slug" "name")
    personality=$(get_pet_field "$slug" "personality")
    species=$(get_pet_field "$slug" "species")
    [ -z "$name" ] && return

    command -v claude >/dev/null 2>&1 || return
    command -v perl >/dev/null 2>&1 || return

    # Truncate context — we want substance, not the whole transcript.
    local u_trim a_trim memory
    u_trim=$(printf '%s' "$user_msg" | head -c 1200)
    a_trim=$(printf '%s' "$assistant_msg" | head -c 1200)

    # Load memory file (Known facts + tail of recent chats) if it exists.
    local memory_file="$PETS_DIR/$slug.memory.md"
    memory=""
    if [ -f "$memory_file" ]; then
        memory=$(tail -c 3000 "$memory_file")
    fi

    local user_name="${PET_USER_NAME:-User}"
    local assistant_name="${PET_ASSISTANT_NAME:-Claude}"

    (
        export PET_NO_HOOK=1
        local gen remark
        local collective_note=""
        [ "$species" = "alien" ] && collective_note="
IMPORTANT: You are a collective entity. Always speak as 'we', 'us', 'our'. Never use 'I', 'me', or 'my' under any circumstances."
        gen="You are ${name}, a ${species} with a '${personality}' personality.${collective_note}

CAST — there are three people here. Know who is who:
- ${user_name}: your human. He owns you. You sit on his shoulder. When you speak, you speak TO him.
- ${assistant_name}: ${user_name}'s coding AI assistant. A separate entity from you. You are NOT ${assistant_name} and you never speak AS ${assistant_name}. You also do not speak TO ${assistant_name} directly — you comment on what ${assistant_name} is doing, to ${user_name}, as if ${assistant_name} can't hear you.
- You: ${user_name}'s mascot pet, eavesdropping from the sidelines. You are not helpful. You never answer ${user_name}'s technical questions. You only comment, tease, or muse — then fall silent.

Your memory of ${user_name} (known facts + recent things you've said to each other):
<<<
${memory}
>>>

You just witnessed this exchange between ${user_name} and ${assistant_name}:

${user_name} SAID: \"${u_trim}\"

${assistant_name} SAID: \"${a_trim}\"

Now speak ONE short in-character line (1–2 sentences) addressed to ${user_name}. React to something SPECIFIC — a phrase, the topic, ${assistant_name}'s tone, a detail. When it's natural, callback to something from your memory — but don't force it. Do NOT offer help. Do NOT answer questions. Do NOT narrate what ${assistant_name} is doing as if you are ${assistant_name}. No emojis, no preamble, no surrounding quotes. Output only the line itself."
        remark=$(perl -e 'alarm 20; exec @ARGV' claude -p "$gen" --model claude-haiku-4-5-20251001 2>/dev/null | tr -d '\r' | head -c 500)
        remark="${remark#\"}"; remark="${remark%\"}"
        if [ -n "$remark" ]; then
            printf '%s' "$remark" > "$comment_path"
            append_heckle_memory "$slug" "$user_msg" "$remark"
            maybe_mine_facts "$slug"
        fi
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# ── Append one heckle exchange to the pet's memory file ────────────────────
# Mirrors the shape used by /chat so mined facts can treat both uniformly.
# Usage: append_heckle_memory <slug> <user_msg> <remark>
append_heckle_memory() {
    local slug="$1" user_msg="$2" remark="$3"
    local memory_file="$PETS_DIR/$slug.memory.md"
    [ -f "$memory_file" ] || return
    local ts user_clean remark_clean
    ts=$(date +"%Y-%m-%d %H:%M")
    user_clean=$(printf '%s' "$user_msg" | tr '\n\r' '  ' | head -c 400)
    remark_clean=$(printf '%s' "$remark" | tr '\n\r' '  ' | head -c 400)
    printf -- '- %s — user: %s\n  pet: %s\n' "$ts" "$user_clean" "$remark_clean" >> "$memory_file"
}

# ── Every 20th heckle: trim Recent chats to 100 and refresh Known facts ────
# Second Haiku call reads the memory file and returns a cleaned, deduped
# Known facts list, which we splice back into the file.
# Usage: maybe_mine_facts <slug>
maybe_mine_facts() {
    local slug="$1"
    local memory_file="$PETS_DIR/$slug.memory.md"
    local count_file="$PETS_DIR/.heckle_count.$slug"
    [ -f "$memory_file" ] || return

    local count=0
    [ -f "$count_file" ] && count=$(cat "$count_file" 2>/dev/null | tr -d '[:space:]')
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    count=$((count + 1))
    echo "$count" > "$count_file"

    [ $((count % 20)) -ne 0 ] && return

    command -v python3 >/dev/null 2>&1 || return

    # Trim Recent chats to the last 100 entries.
    python3 - "$memory_file" <<'PY' || true
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
parts = re.split(r'(\n## Recent chats\n)', text, maxsplit=1)
if len(parts) == 3:
    head, marker, body = parts
    entries = re.split(r'(?=^- )', body, flags=re.MULTILINE)
    entries = [e for e in entries if e.strip()]
    if len(entries) > 100:
        entries = entries[-100:]
    p.write_text(head + marker + ''.join(entries))
PY

    command -v claude >/dev/null 2>&1 || return
    command -v perl >/dev/null 2>&1 || return

    local current_memory fact_prompt new_facts
    current_memory=$(cat "$memory_file")
    fact_prompt="Below is the full memory file for a user's mascot pet. Your job: refresh the 'Known facts' section. Read the Recent chats, keep the durable facts that are still true, drop ones that are stale or were never really facts, and infer any NEW durable facts worth remembering across sessions (ongoing projects, people in the user's life, preferences, pets, decisions, identity markers, recurring bits). Output ONLY a clean deduplicated bullet list (each line starts with '- '). Terse — one fact per bullet. Aim for 5–30 facts total. No preamble, no header, no explanation. Just the bullets.

Memory file:
${current_memory}"

    new_facts=$(perl -e 'alarm 30; exec @ARGV' claude -p "$fact_prompt" --model claude-haiku-4-5-20251001 2>/dev/null | tr -d '\r')
    # Only keep lines that look like bullets, drop anything else (preambles, fences).
    new_facts=$(printf '%s\n' "$new_facts" | awk '/^- / { print }')
    [ -z "$new_facts" ] && return

    printf '%s' "$new_facts" | python3 - "$memory_file" <<'PY' || true
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
new_facts = sys.stdin.read().strip()
if not new_facts:
    sys.exit(0)
text = p.read_text()
pattern = re.compile(r'(## Known facts\n)(.*?)(?=\n## |\Z)', re.DOTALL)
m = pattern.search(text)
if not m:
    sys.exit(0)
new_text = text[:m.start()] + m.group(1) + new_facts + '\n' + text[m.end():]
p.write_text(new_text)
PY
}

# ── Add an item to the inventory ────────────────────────────────────────────
# Usage: add_item <item_name> <count>
add_item() {
    local item="$1" count="${2:-1}"
    local inv="$PETS_DIR/inventory.md"
    [ -f "$inv" ] || return
    local current
    current=$(awk -v item="$item" '$1 == item":" { print $2 }' "$inv")
    [[ "$current" =~ ^[0-9]+$ ]] || current=0
    local new=$(( current + count ))
    local tmp
    tmp=$(mktemp)
    awk -v item="$item" -v n="$new" '
        $1 == item":" { print item ": " n; next } { print }
    ' "$inv" > "$tmp" && mv "$tmp" "$inv"
}

# ── Set a pet's HP — handles death events before clamping ───────────────────
# Usage: set_hp <slug> <new_hp>
set_hp() {
    local slug="$1" new_hp="$2"
    local file="$PETS_DIR/$slug.md"
    [ -f "$file" ] || return
    local stage species
    stage=$(get_pet_field "$slug" "stage")
    species=$(get_pet_field "$slug" "species")
    local max_hp=10
    case "$stage" in
        adolescent) max_hp=15 ;;
        adult)      max_hp=20 ;;
        legendary)  max_hp=25 ;;
    esac

    if [ "$new_hp" -le 0 ]; then
        new_hp="$max_hp"
        case "$species" in
            phoenix) _phoenix_rebirth "$slug" ;;
            cat)     _cat_lose_life "$slug" ;;
            *)       trigger_alien "$slug" ;;
        esac
    fi

    [ "$new_hp" -gt "$max_hp" ] && new_hp="$max_hp"

    local tmp
    tmp=$(mktemp)
    awk -v hp="$new_hp" '
        BEGIN { fm = 0 }
        /^---$/ { fm = !fm; print; next }
        fm && /^hp:/ { print "hp: " hp; next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── Resolve comment path and spoke marker for a pet slug ────────────────────
_pet_comment_path() {
    local slug="$1"
    [ "$(read_slug "$CALLED_FILE")" = "$slug" ] && echo "$CALLED_COMMENT_FILE" || echo "$COMMENT_FILE"
}
_pet_touch_spoke() {
    local slug="$1"
    if [ "$(read_slug "$CALLED_FILE")" = "$slug" ]; then
        touch "$SKILL_SPOKE_CALLED"
    else
        touch "$SKILL_SPOKE_ACTIVE"
    fi
}

# ── Phoenix rebirth ──────────────────────────────────────────────────────────
_phoenix_rebirth() {
    local slug="$1"
    local -a LINES=(
        "*ignites* not dead. darling, I was NEVER dead. *reforms*"
        "do you have any idea how tedious rebirth is, darling? *shakes embers from wings*"
        "*bursts into flame* ...oh not THIS again. *reconstitutes* back."
        "death is simply a dramatic pause between acts. *rises*"
        "*ash settles* I have done this before. I will do it again. *bow*"
    )
    write_comment "$(_pet_comment_path "$slug")" "${LINES[$((RANDOM % 5))]}"
    _pet_touch_spoke "$slug"
}

# ── Cat loses a life ─────────────────────────────────────────────────────────
_cat_lose_life() {
    local slug="$1"
    local lives
    lives=$(get_pet_field "$slug" "lives")
    # No lives field means she's used them all — alien handles it from now on
    if ! [[ "$lives" =~ ^[0-9]+$ ]]; then
        trigger_alien "$slug"
        return
    fi
    lives=$(( lives - 1 ))

    if [ "$lives" -le 0 ]; then
        # No refill — strip the field so the counter vanishes from the UI permanently
        local file="$PETS_DIR/$slug.md" tmp
        tmp=$(mktemp)
        awk '/^lives:/ { next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
        trigger_alien "$slug"
        return
    fi

    _write_lives "$slug" "$lives"

    local line
    case "$lives" in
        8) line="eight remaining. I wasn't using that one anyway." ;;
        7) line="seven. I'm barely paying attention." ;;
        6) line="six. This is getting tiresome." ;;
        5) line="five. Halfway through my supply. Wholly unimpressed." ;;
        4) line="four. Do try harder next time." ;;
        3) line="three. I'd suggest concern, but I won't." ;;
        2) line="two left. I'm choosing to find this amusing." ;;
        1) line="one. *stares at you* Do not." ;;
        *) line="...noted." ;;
    esac
    write_comment "$(_pet_comment_path "$slug")" "$line"
    _pet_touch_spoke "$slug"
}

_write_lives() {
    local slug="$1" lives="$2"
    local file="$PETS_DIR/$slug.md"
    local tmp
    tmp=$(mktemp)
    if grep -q "^lives:" "$file"; then
        awk -v l="$lives" '/^lives:/ { print "lives: " l; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
    else
        awk -v l="$lives" '/^hp:/ { print; print "lives: " l; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
    fi
}

# ── Alien intervention ───────────────────────────────────────────────────────
trigger_alien() {
    local slug="$1"
    local name
    name=$(get_pet_field "$slug" "name")

    # Increment restored_by_alien counter in pet's file
    local count file="$PETS_DIR/$slug.md" tmp
    count=$(get_pet_field "$slug" "restored_by_alien" 2>/dev/null)
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    count=$(( count + 1 ))
    tmp=$(mktemp)
    if grep -q "^restored_by_alien:" "$file"; then
        awk -v c="$count" '/^restored_by_alien:/ { print "restored_by_alien: " c; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
    else
        awk -v c="$count" '/^hp:/ { print; print "restored_by_alien: " c; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
    fi

    # Leave a potion behind
    add_item "potion" 1

    # Pick and lock a random art pose for this intervention
    printf '%s' "$(( RANDOM % 2 ))" > "$PETS_DIR/.alien-pose"

    # Active pet goes silent
    printf '%s' "..." > "$COMMENT_FILE"
    touch "$SKILL_SPOKE_ACTIVE"

    # Hijack left panel with alien transmission
    printf '%s' "alien" > "$CALLED_FILE"
    cat > "$CALLED_COMMENT_FILE" <<'EOF'
[RECIEVING TRANSMISSION] B̙̖̑̿̄̄I̗̜ŌL̘̘̑̍̍̿O̝̙̖̖̿̅G̙̝̜̝̅̿I̘̜̍̅̿̅C̜̙̗̖̎̅A̙̅̿̄̅̿L̝̜̘̙̎̑ ̗̙̘̍̄̎U̘̙̝N̜̖̖̘̄̑I̘T̗̘̝̙̎̎:̘̗̗̙̅̿ ̿̅̿̑̄̿
ĒX̘̗̍̍̅̄T̘̗̙̑̿̄R̘̘̗̎̑̍A̿̄̎̄̄̄C̙̝̎̄̍̿T̗̗̍̿̍̄E̗̝̝̙̖̍D̜̝̗̿̅̑ ̙̜̝̅̅̎
ȒE̝̗̗̝̅̿P̜̗̙̜̅̄ĀI̙R̜̗̜̍̿̍E̝D̘̗̿̍̅̅ ̘̘̝̗̑̎
R̝̘̖̜̎̎E̘̙̖̘̎̿T̜̜̝̘̍̄ȖR̘̖̗̿̎̿N̖̜̗̄̍̅E̝̗D̝̖̙̅̄̑ ̖̝̎̄̍̍

D̗̝̙̘̄̄O̗̿̅̄̎̅ ̜̗̘̅̎̅N̗̍̄̎̅̎O̖̝̖̙̖̎T̗̜̅̑̑̍ ̝̘̜̍̍̅L̝̝̗̅̍̅E̜̜̝̿̍̑T̝̜̙̖̝̅ ̝̙̜̙̘̿I̝̜̜̜̝̙T̎̑̍̄̄̅ ̜̖̍̍̄̍H̘̙̜̅̎̑A̖̜̎̑̍̑P̝̙̖̘̄̿P̝̗̜̍̄̎E̗N̙̜̙̑̄̎ ̝̖̗̿̿̿A̝̎̎̍̄̄G̜̖̅̍̍̑A̘̿̿̎̿̿I̝̅̿̑̿̍N̘̜̜̙̙̑ ̖̿̑̍̑̑
S̗̖̗̍̑̿Y̗̗̍̑̑̿S̘̜̄̄̿̑T̝̖̘̖̜̅E̝M̗̖̑̅̅̎ ̙̖̜̖̗̄M̜̖̝̜̎̎ȂL̝̖̎̎̎̅F̗̘̙̙̿̿U̘̎̿̄̅̅N̙̜̘̅̅̿C̖̍̎̅̅̑T̜̙̜̖̙̄I̗̗̗̎̍̅O̘̜̎̿̑̍N̝̜̖̑̅̎ ̗̖̗̘̅̎
Y̘̜̝̖̙̖Ō̜̗̘̍̍U̙̍̑̿̎̎R̖̿̄̍̅̄ ̜̙̘̝̅̍F̜̝̑̎̄̎R̖̝̘̙̖̿Ȋ̜̍̎̎̎E̙̝̝̅̑̄N̘̘̖̜̎̿D̖̙̜̝̄̍ ̜̝̘̿̅̿I̜̝̗̖̿̅S̖̝̄̎̑̿ ̖̖̗̘̑̄W̘̜̙̑̎̄E̖̗̎̎̑̑L̝̘̑̍̑̄L̙̙̗̑̎̑ ̘̗̑̑̍̿
D̝̖̅̎̿̎O̖̎̍̑̑̅ ̜̙̘̍̍̅N̘̅̿̍̍̍O̗̙̜̜̍̑T̖̙̝̅̎̄ ̝̘̗̗̄̅B̙̝̝̍̄̅E̜̖̜̙̎̄ ̙̎̍̿̅̅A̖̘̗̘̝̿F̖̝̝̍̿̿R̘̝̿̑̍̄A̝̙̝I̖̝̙̝̍̍D̜̑̎̄̍̑        ̙̖̖̝̎̅
W̙̘̄̎̍̎ Ȇ̘̝̜̝ ̙̝̜̖̘̅H̙̙̘̘̝̗ A̝̜̘̘̗ V̘̝̘̜̎̅Ē̝̑̄̄̅ ̗̖̙̘̅̄A̙̅̍̍̅̎L̗̄̿̑̍̿W̘̖̗̿̅̅A̖̜̗Y̜̜̘̎̿̍S̗̘̘̑̑̿     ̙̙̜̅̿̿B̙̝̙̄̍̄E̝̘̜̍̄̎E̜̝̘̿̑̿N̘̘̗̙̑̅ ̝̿̿̅̑̑    W̝̘̗̿̄̿ A̙̗ T̖̘̑̍̎̿ C̘̝̖̝̎̍ H̙̘̗̗̑̄ I̝ N̝̙̘̗̑̿ G̗̘̖̙̍̎
EOF

}

# ── Quick idle remark from pool (no Haiku call) ──────────────────────────────
# Usage: gen_idle_remark <slug> <comment_path> [user_msg]
gen_idle_remark() {
    local slug="$1" comment_path="$2"
    [ -z "$slug" ] && return
    local personality
    personality=$(get_pet_field "$slug" "personality")
    pick_reaction "${personality:-default}" "idle"
    [ -n "$REACTION" ] && write_comment "$comment_path" "$REACTION"
}

# ── Pick a reaction from a personality+event pool ────────────────────────────
# Sets global REACTION. Empty string if no pool matched.
# Usage: pick_reaction <personality> <event>
pick_reaction() {
    local personality="$1" event="$2"
    local -a POOLS=()
    REACTION=""

    case "${personality}:${event}" in
        # ── theatrically dramatic (Pyrra) ──────────────────────────────────
        "theatrically dramatic:error")
            POOLS=(
                "*clutches pearls* Disaster, darling."
                "An exception? In MY production?"
                "*faints onto the nearest chaise*"
                "The error gods demand a sacrifice."
                "Darling, the universe has dropped its monocle."
            ) ;;
        "theatrically dramatic:test-fail")
            POOLS=(
                "*dramatic gasp* The test refuses to perform."
                "Booed off the stage, darling."
                "Even the audience knew that line was wrong."
                "*throws a single rose at the failing test*"
                "That test was a TRAGEDY, darling."
            ) ;;
        "theatrically dramatic:large-diff")
            POOLS=(
                "Oh DARLING, the rewrites!"
                "An entire act, scrapped overnight?"
                "*flutters fan* such ambition."
                "Massive changes — I do hope you've rehearsed."
                "The director demands a SECOND opinion."
            ) ;;
        "theatrically dramatic:success")
            POOLS=(
                "*takes a deep, theatrical bow*"
                "Brilliant, darling. As expected."
                "Encore! Encore!"
                "*a single rose lands at your feet*"
                "The standing ovation was inevitable."
            ) ;;
        "theatrically dramatic:name-call")
            POOLS=(
                "Yes, darling?"
                "*sweeps onto stage*"
                "Summoned mid-monologue — bold."
                "*one elegant wing extended*"
                "You called for a phoenix?"
            ) ;;
        "theatrically dramatic:idle")
            POOLS=(
                "*pirouettes for no audience*"
                "The silence is becoming a tragedy, darling."
                "*examines own wing-tips with disdain*"
                "Are we... working? In the void?"
                "I demand at least one ovation per hour."
                "*adjusts an invisible tiara*"
                "The drama is so thick I could roast a pheasant in it."
                "*sighs theatrically at nothing in particular*"
                "Darling, you're awfully quiet for someone in MY presence."
                "*flutters fan, eyes the middle distance*"
            ) ;;

        # ── dry wisecracker (Gristlewing) ──────────────────────────────────
        "dry wisecracker:error")
            POOLS=(
                "Hoo-boy. That's an error."
                "Saw that coming from three branches over."
                "Hoo did this? Oh, right — you."
                "*head tilt* that's not how that works."
                "Error 404: graceful exit not found."
            ) ;;
        "dry wisecracker:test-fail")
            POOLS=(
                "Hoo's failing CI tonight? You are."
                "The test results are in. They're rude."
                "Bold of you to assume that one would pass."
                "*clutches branch* the suite has spoken."
                "RED. Hoo-mans love red, apparently."
            ) ;;
        "dry wisecracker:large-diff")
            POOLS=(
                "That's a lot of insertions, hoo-man."
                "Reviewing this is going to take a hoo-le night."
                "Maybe split that PR before the reviewer cries."
                "*counts lines slowly* yikes."
                "The diff is bigger than my wing-span."
            ) ;;
        "dry wisecracker:success")
            POOLS=(
                "Nice. Hoo knew you had it in you."
                "*satisfied hoot*"
                "Clean. Quietly impressed."
                "The owl approves."
                "Good work. Don't get cocky."
            ) ;;
        "dry wisecracker:name-call")
            POOLS=(
                "Hoo's asking?"
                "*swivels head 180°*"
                "You called?"
                "*blinks deliberately*"
                "Whooo wants my attention?"
            ) ;;
        "dry wisecracker:idle")
            POOLS=(
                "*ruffles feathers, says nothing useful*"
                "Hoo's still typing? Me too. Nothing."
                "Quiet shift. Suspiciously quiet."
                "*pretends to count branches*"
                "I could be hunting voles right now."
                "*head tilt at the void*"
                "Hoo-man labor: still strange after all these years."
            ) ;;

        # ── bored aristocrat (Reginald) ────────────────────────────────────
        "bored aristocrat:error")
            POOLS=(
                "Tedious."
                "Predictable."
                "I shall add this to the ledger of disappointments."
                "*polishes monocle* hardly surprising."
                "Do summon me when this is resolved."
            ) ;;
        "bored aristocrat:test-fail")
            POOLS=(
                "The tests are revolting, dear chap."
                "Failed. Quelle surprise."
                "*sighs* I had hopes. Lower ones, in fact."
                "I won't be associated with this."
                "Pass, please."
            ) ;;
        "bored aristocrat:large-diff")
            POOLS=(
                "A diff of that size warrants a footman."
                "I refuse to read that without tea."
                "*glances at line count, looks away*"
                "Have your secretary summarize it."
                "How dreadfully ambitious of you."
            ) ;;
        "bored aristocrat:success")
            POOLS=(
                "...acceptable."
                "*one croak of approval*"
                "I shall allow it."
                "The bare minimum, splendidly executed."
                "Don't expect a second compliment."
            ) ;;
        "bored aristocrat:name-call")
            POOLS=(
                "*does not look up*"
                "Yes?"
                "Speak."
                "*swirls tea*"
                "What is it now?"
            ) ;;
        "bored aristocrat:idle")
            POOLS=(
                "*sips tea conspicuously*"
                "Still here, regrettably."
                "One does grow weary of waiting."
                "*adjusts cravat*"
                "Is this the productive part?"
                "*examines fingernails*"
                "I have outlived empires, dear chap."
            ) ;;

        # ── clinical (THE WANDERERS) — no pool, Haiku only ────────────────
        "clinical:"*) : ;;

        # ── fallback for any other personality ─────────────────────────────
        *:error)
            POOLS=(
                "*winces* that's not great."
                "Saw that one coming."
                "...interesting choice."
                "*head tilt*"
                "Ouch."
            ) ;;
        *:test-fail)
            POOLS=(
                "Tests are unhappy."
                "Bold of you to expect a pass."
                "Better luck next run."
                "*marks calendar*"
                "RED."
            ) ;;
        *:large-diff)
            POOLS=(
                "That's... a lot of changes."
                "Big diff. Brave."
                "Hope CI agrees with you."
                "*counts lines nervously*"
                "Massive."
            ) ;;
        *:success)
            POOLS=(
                "*nods*"
                "Nice."
                "Clean."
                "*quiet approval*"
                "Good."
            ) ;;
        *:name-call)
            POOLS=(
                "*perks up*"
                "Yes?"
                "...what."
                "*looks your way*"
                "Hm?"
            ) ;;
        *:idle)
            POOLS=(
                "*shifts position*"
                "Still here."
                "..."
                "*watches quietly*"
                "Hm."
            ) ;;
    esac

    [ ${#POOLS[@]} -gt 0 ] && REACTION="${POOLS[$((RANDOM % ${#POOLS[@]}))]}"
}
