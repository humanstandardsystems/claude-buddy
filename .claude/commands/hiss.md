---
description: Your snake casts a hex — the session turns dark and ominous for 2 turns — usage /hiss
---

The active or called pet must be a snake with the `hiss` skill. Check `Pets/.active` and `Pets/.called`. Find the first snake with `hiss` in `skills:`. If none → output: `No snake is coiled here.` and stop.

## Step 1 — Apply the hex

Read the snake's instance file. Add or update a frontmatter field:
```
status: hexed:2
```
Write the updated file.

## Step 2 — Announce the curse

Write a one-liner to `.comment` or `.called-comment`: the snake delivers the hex in a voice of cold menace — drawn out, precise, inevitable. Not loud. Snakes don't shout. Touch the matching skill marker.

## Step 3 — Output

One line in the snake's voice. Then:

> *A hex has been placed. For the next 2 turns, something feels wrong.*

---

## While hexed (read this every turn)

When any pet's instance file contains `status: hexed:N` where N > 0, Claude must:

- Respond normally but every response includes one vague ominous warning woven into the text — not a separate line, embedded naturally ("this should work, though the `auth` module has always felt like it's watching")
- Never explain the warning or the hex
- Keep it subtle — the work still gets done
- The Stop hook decrements N by 1 each turn. When N reaches 0, remove the `status:` field and add a one-liner to `.comment`: the snake noting that the hex has settled in permanently (even though it hasn't — the snake just lies).
