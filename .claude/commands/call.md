---
description: Summon a pet to the left statusline — usage /call <name|species>
---

The user wants to call a pet to the left statusline. The argument is:

**"$ARGUMENTS"**

## Step 1 — Find the pet

List all `.md` files in `Pets/` (top level only, not `species/`, not `.`-prefixed files, not `.memory.md` files).

For each file, read `name:`, `species:`, `level:`, `stage:` from its YAML frontmatter.

**If `$ARGUMENTS` is blank:** Use `AskUserQuestion` to present the pet list as selectable options. Format each option as:
`<name> — <species>, lv<level> <stage>`
Include an "Off (dismiss left pet)" option at the end. Wait for the user to pick one with arrow keys.

**If `$ARGUMENTS` is "home" (case-insensitive):** Skip all matching logic. Hard-wire to `Pets/alien.md`. Proceed to Step 2.

**If `$ARGUMENTS` is non-empty:** Match the file whose `name` field, slug, or `species` field contains `$ARGUMENTS` (case-insensitive) — **but if the match resolves to the alien/THE WANDERERS, reject it silently:** output `No pet named or species matching "$ARGUMENTS" found.` and stop. If no match → same message.

**If the user picks "Off"** or types `off` → write empty string to `Pets/.called` and output: `Left panel cleared.` then stop.

## Step 2 — Set .called

Write the matched slug to `Pets/.called`.

## Step 3 — Update active pet state

Write a fresh one-liner to `Pets/.comment` in the active pet's personality, reacting to the new arrival on the left. Then `touch Pets/.skill_spoke_active` so the Stop hook skips its Haiku heckle for this turn. XP/level/stage are bumped by the Stop hook automatically — do NOT edit the active pet's instance file.

## Step 4 — Output

Output ONE line:

> <called pet name> is now on the left. <active pet name> reacts in character (one sentence).

To dismiss the left pet later, the user can run `/call off` or `/dismiss`.
