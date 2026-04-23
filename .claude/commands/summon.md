---
description: Summon a pet to the active right-panel slot — usage /summon [name]
---

The user wants to change which pet is in the active (right-panel) slot. The argument is:

**"$ARGUMENTS"**

## Step 1 — Find the pet

List all `.md` files in `Pets/` (top level only, not `species/`, not `.`-prefixed files, not `.memory.md` files).

For each file, read `name:`, `species:`, `level:`, `stage:` from its YAML frontmatter.

**If `$ARGUMENTS` is non-empty:** Match the file whose `name:` field or slug contains `$ARGUMENTS` (case-insensitive). If no match → output: `No pet named "$ARGUMENTS" found.` and stop. Skip the picker entirely.

**If `$ARGUMENTS` is blank:** Use `AskUserQuestion` to present up to 4 pets as selectable options (exclude the currently active pet since selecting it would be a no-op). Format each option as:
`<name> — <species>, lv<level> <stage>`
If there are more than 4 inactive pets, show the 4 with the highest XP — the rest are reachable by running `/summon <name>` directly.

**If the chosen pet is already active** (slug matches `Pets/.active`) → output: `<name> is already your active buddy.` and stop.

## Step 2 — Update the incoming pet's state

Read the chosen pet's instance file. Increment `encounters` by 1 and update `last_seen` to today. Write the updated file. Do NOT touch `xp`, `level`, or `stage` — the Stop hook handles those.

## Step 3 — Set .active

Write the chosen pet's slug to `Pets/.active`.

## Step 4 — Write comment

Write a fresh one-liner to `Pets/.comment` in the newly active pet's personality, reacting to being switched in (e.g., excitement, annoyance, theatrical entrance — stay in character).

Then `touch Pets/.skill_spoke_active` so the Stop hook skips its Haiku heckle for this turn.

## Step 5 — Output

Output ONE line:

> <new pet name> is now your active buddy. (one-sentence in-character reaction)
