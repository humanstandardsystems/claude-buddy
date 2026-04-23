---
description: Teach a skill to the active pet — usage /teach <skill>
---

The user wants to give a skill to a pet. Arguments: **"$ARGUMENTS"**

## Step 1 — Parse arguments

The skill name is the first word of `$ARGUMENTS`. Always teach to the **active pet** — read `Pets/.active` for the slug. If `.active` is empty → output: `No active buddy. Run /buddy to summon one.` and stop.

## Step 2 — Find the pet

Read `Pets/<active-slug>.md`.

## Step 3 — Validate the skill

Check if the skill name matches any existing command file in `.claude/commands/` OR any custom skill file in `Pets/skills/` (if that folder exists).

**If skill is snake-exclusive (`hiss`):** Only snakes can have it. If pet is not a snake → output: `<skill> can only be taught to snakes.` and stop.

**If skill is `heal`:** Snakes cannot learn it. If pet is a snake → output: `Snakes cannot heal.` and stop.

**If skill already in pet's `skills:` list:** output: `<pet name> already knows <skill>.` and stop.

**If skill doesn't exist anywhere:** output: `Unknown skill: <skill>. Check /use for custom skills or create one in Pets/skills/.` and stop.

## Step 4 — Teach it

Add the skill to the pet's `skills:` list in frontmatter. Write the updated file.

Write a one-liner to the pet's `.comment` or `.called-comment` (whichever applies) in the pet's personality, reacting to learning this new skill. Touch the matching skill marker.

## Step 5 — Output

`<pet name> learned <skill>.`

Then the pet's one-liner reaction.
