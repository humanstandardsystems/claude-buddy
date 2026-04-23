---
description: Send a hunter pet out to find food — usage /hunt
---

Only a **cat, dog, owl, phoenix, or snake** can hunt. Check `Pets/.active` first, then `Pets/.called`. Find the first pet whose `species:` field is one of those five. If none → output: `No hunter is present. (Cats, dogs, owls, phoenixes, and snakes only.)` and stop.

## Step 1 — Roll for loot

Pick a number 1–100 (use the current Unix timestamp modulo 100 + 1 as your d100).

| Roll | Result |
|------|--------|
| 1–15 | Bad hunt — pet returns injured, no food |
| 16–45 | Berry (+1 berry) |
| 46–75 | Treat (+1 treat) |
| 76–95 | Steak (+1 steak) |
| 96–100 | Potion (+1 potion) |

## Step 2a — Good hunt (roll 16–100)

Add the item to `Pets/inventory.md` by incrementing the matching line (e.g. `berry: N` → `berry: N+1`).

Write a one-liner to the pet's `.comment` or `.called-comment` in their personality: the hunter returns triumphant, describing the find in character. Touch the matching skill marker.

## Step 2b — Bad hunt (roll 1–15)

The pet returns empty-pawed and slightly worse for wear. Subtract 3 HP (floor at 1). Read the current `hp:` field from the pet's instance file, subtract 3, clamp to 1, write it back.

Write a one-liner to `.comment` or `.called-comment`: the hunter limps back, in character. Touch the matching skill marker.

## Step 3 — Output

One descriptive line from the hunter's perspective (the hunt itself — brief, vivid, in character).

Then on the next line:
- Good: `+1 <item> added to inventory.`
- Bad: `Returned empty. <pet name> lost 3 HP. (HP: <new>/<max>)`
