---
description: Have your turtle issue a slow, low-stakes coding challenge — usage /challenge
---

The active or called pet must be a turtle with the `challenge` skill. Check `Pets/.active` and `Pets/.called`. Find the first turtle with `challenge` in `skills:`. If none → output: `No turtle is present to issue the challenge.` and stop.

## Step 1 — Issue the challenge

Generate one small, specific, low-stakes coding challenge appropriate to the current project context. Rules:
- It must be completable in under 10 minutes
- It must be genuinely useful (refactor one function, name one variable better, add one missing edge case check)
- It must be stated as a dare, not a task ("I dare you to make this function do exactly one thing")
- The turtle delivers it slowly, with great gravitas, as if issuing an ancient trial

Write the challenge to `.comment` or `.called-comment` in the turtle's personality. Touch the matching skill marker.

## Step 2 — Track it

Write the challenge text to `Pets/.active-challenge` (plain text). This lets `/complete` or future commands check if the user finished it.

## Step 3 — Output

`<turtle name> has issued a challenge:`

Then the challenge on a new line, in the turtle's voice. Then:

> *Complete it to earn +5 XP for <turtle name>.*
