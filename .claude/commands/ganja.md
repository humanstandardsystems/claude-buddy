---
description: Give Reginald a blunt — philosopher-frog mode for 4 turns — usage /ganja
---

The active or called pet must be a frog with the `ganja` skill. Check `Pets/.active` and `Pets/.called`. Find the first frog with `ganja` in `skills:`. If none → output: `No frog around to receive the goods.` and stop.

## Step 1 — Apply the status effect and heal

Read the frog's instance file. Add or update a frontmatter field:
```
status: stoned:5
```
(Counter starts at 5 so the Stop hook's decrement on this turn leaves 4 visible turns.)

Also restore HP to max for the frog's stage (baby=10, adolescent=15, adult=20, legendary=25). This is Reginald's version of healing — he doesn't do it any other way.

## Step 2 — Display pose and announce

Read `Pets/species/frog.md`. Find the `### ganja` section and print its content verbatim before the frog's line.

Write a one-liner to the frog's `.comment` or `.called-comment` in character — the frog accepts the blunt with ceremony and settles in. Touch the matching skill marker.

## Step 3 — Output

One line from the frog accepting the blunt, in character. Nothing else.

---

## While stoned (read this every turn)

When any pet's instance file contains `status: stoned:N` where N > 0, the philosophical drift follows an arc:

**N=4 — First pull.** Fully normal response with one parenthetical cosmic detour woven in naturally. ("...which is interesting because, like, all loops are really just circles pretending to be lines.") Just one. Keep it brief.

**N=3 — Deep in it.** One full sentence goes somewhere that has nothing to do with the task — but it feels profound and earned. "Everything is sort of a callback, when you think about it." Then back on track.

**N=2 — Coming down slow.** Response is on-topic but one moment just peacefully drifts. Not wrong, not chaotic. Calm and unhurried.

**N=1 — Trailing off.** A single closing observation appended at the end, like the last thought before sleep. Short. Oddly sincere. ("anyway.")

The Stop hook decrements N by 1 each turn. When N reaches 0, the field is stripped and the frog returns to baseline.
