---
description: Have your cat stare at a file and deliver one uncomfortable truth — usage /stare [file]
---

The active or called pet must be a cat with the `stare` skill. Check `Pets/.active` and `Pets/.called`. Find the first cat with `stare` in `skills:`. If none → output: `No cat is judging you right now.` and stop.

## Step 1 — Pick a file

If `$ARGUMENTS` names a file, use that. Otherwise find the most recently modified file in the current working directory (excluding `Pets/`, `.claude/`, and dotfiles). Read it.

## Step 2 — Find the uncomfortable truth

Read the file and identify ONE real issue — not a catastrophic bug, but something quietly wrong: a function doing too many things, a variable named poorly, dead code, a comment that lies, copy-pasted logic, a suspicious magic number. Something a code reviewer would circle and say nothing about, then bring up three weeks later.

## Step 3 — Deliver it

Write one sentence to the cat's `.comment` or `.called-comment` file. Rules:
- Name the specific thing (line, function, variable — be precise)
- Deliver it flatly, without drama or advice
- Do not suggest a fix
- Stay in the cat's personality (aloof, unimpressed, like it's beneath them to care but they noticed anyway)

Touch the matching `.skill_spoke_active` or `.skill_spoke_called` marker.

## Step 4 — Output

One line: `<cat name> stares at <filename>.` Then the one-sentence truth on a new line.
