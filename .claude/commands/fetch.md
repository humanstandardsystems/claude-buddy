---
description: Have your dog fetch something from your codebase — usage /fetch [what]
---

The active or called pet must be a dog with the `fetch` skill. Check `Pets/.active` and `Pets/.called`. Find the first dog with `fetch` in `skills:`. If none → output: `No dog here to fetch anything.` and stop.

## Step 1 — Decide what to fetch

If `$ARGUMENTS` is provided, use it as the search target (e.g. "TODOs", "longest function", "dead code", "magic numbers").

If blank, pick one at random from this list:
- All TODO/FIXME/HACK comments
- The longest function (by line count)
- Duplicate or near-duplicate code blocks
- Unused imports or variables
- Functions with more than 3 parameters

## Step 2 — Go fetch

Search the codebase (current working directory, excluding `node_modules/`, `.git/`, `Pets/`). Find real instances of the target. Collect up to 5 results with file paths and line numbers.

## Step 3 — Drop it at your feet

Write one excited sentence to `.comment` or `.called-comment` in the dog's personality (enthusiastic, proud, tail-wagging energy — they found a thing and they brought it to you). Touch the matching skill marker.

## Step 4 — Treat chance

Roll d10 (0–9). On 0, 1, or 2 (30% chance): add 1 treat to `Pets/inventory.md` by incrementing the `treat:` line. Announce this in the dog's excited voice as a brief aside after the results.

## Step 5 — Output

`<dog name> fetched: <what was searched>`

Then list the results with file:line format. Keep it tight — paths and the relevant snippet only, no explanation.

If a treat was found: `(+1 treat dropped in inventory)`
