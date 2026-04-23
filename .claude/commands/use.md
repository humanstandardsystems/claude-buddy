---
description: Use a custom skill from Pets/skills/ — usage /use <skill name>
---

The user wants to invoke a custom skill. Arguments: **"$ARGUMENTS"**

Custom skills live in `Pets/skills/<skill-name>.md`. These are user-defined skill definitions — not built-in commands.

## Step 1 — Check the active pet

Read `Pets/.active`. If empty → output: `No active buddy.` and stop.

Read the active pet's instance file. Check that `$ARGUMENTS` appears in its `skills:` list. If not → output: `<pet name> doesn't know <skill>. Use /teach <skill> to teach it first.` and stop.

## Step 2 — Find the skill definition

Look for `Pets/skills/$ARGUMENTS.md`. If it doesn't exist → output: `No skill definition found for "<skill>". Create Pets/skills/<skill>.md to define it.` and stop.

## Step 3 — Execute the skill

Read `Pets/skills/$ARGUMENTS.md`. This file contains the skill's behavior definition written by the user. Execute it as Claude instructions, in the context of the current session and the active pet's personality.

## Step 4 — Output

Whatever the skill definition specifies. The active pet is always the one delivering the skill — stay in character throughout.
