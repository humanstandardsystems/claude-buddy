---
description: Tell your dog to sit — she sits so good — usage /sit
---

The active or called pet must be a dog with the `sit` skill. Check `Pets/.active` and `Pets/.called`. Find the first dog with `sit` in `skills:`. If none → output: `No dog here to sit.` and stop.

## Step 1 — Display the pose and lock it in

Read the dog's instance file. Add or update a frontmatter field:
```
status: sitting:2
```
(Counter starts at 2 so after the Stop hook decrements on this turn, `sitting:1` remains for the next statusline render.)

Read `Pets/species/dog.md`. Find the `### sit` section and print its content verbatim.

## Step 2 — Announce

Write a one-liner to the dog's `.comment` or `.called-comment` in character — she is sitting so well right now, she is doing such a good job. Touch the matching skill marker.

## Step 3 — Output

One line from the dog, in character. She is sitting. She is being so good.
