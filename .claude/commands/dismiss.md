---
description: Dismiss the left-panel called pet — usage /dismiss
---

The user wants to dismiss the pet currently in the left panel (set via `/call`).

The main active heckler pet is NEVER dismissed by this command. It only goes idle after 24 hours of inactivity.

## Steps

### Step 1 — Check state

Read `Pets/.called`.

If it is empty, output: `No pet on the left panel.` and stop.

If `.called` contains `alien`, output: `They do not leave when asked.` and stop.

### Step 2 — Active pet reacts

Read the active pet's instance file (slug from `Pets/.active`) for personality. Write a fresh one-liner to `Pets/.comment` in the active pet's personality, reacting to the left pet's departure. Then `touch Pets/.skill_spoke_active` so the Stop hook skips its Haiku heckle. XP/level/stage are bumped by the Stop hook automatically — do NOT edit the active pet's instance file.

### Step 3 — Clear left-panel files

- `Pets/.called` → write empty string
- `Pets/.called-comment` → write empty string

### Step 4 — Output

One line, e.g.:
`Madame Pyrra Von Ashcroft has been dismissed from the left panel.`
