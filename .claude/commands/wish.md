---
description: Make a wish — your unicorn attempts to grant it — usage /wish <your wish>
---

The active or called pet must be a unicorn with the `wish` skill. Check `Pets/.active` and `Pets/.called`. Find the first unicorn with `wish` in `skills:`. If none → output: `No unicorn is here to grant wishes.` and stop.

If `$ARGUMENTS` is blank → output: `<unicorn name> waits, horn glowing. State your wish.` and stop.

## Step 1 — Interpret the wish

Read `$ARGUMENTS` as a wish. Wishes can be vague ("I wish this was cleaner"), specific ("I wish that function had a better name"), or impossible ("I wish this project was done"). Classify it:

- **Actionable** — something Claude can actually attempt right now (rename, refactor, find something, generate something)
- **Aspirational** — a real goal but too large for one action (unicorn acknowledges it and breaks it into the single next step)
- **Impossible** — not a real coding task (unicorn delivers a whimsical non-answer)

## Step 2 — Attempt the grant

**Actionable:** Do the thing. Make the change, find the file, generate the output. Then write to `.comment` or `.called-comment`: unicorn announces the grant with quiet magic, no fanfare. Touch the skill marker.

**Aspirational:** Identify the one concrete next step toward the wish. Present it clearly. Write to `.comment`: unicorn acknowledges the wish is large but points toward the horizon.

**Impossible:** Write to `.comment`: unicorn delivers a beautiful, useless, poetic non-answer. No apology. Just magic.

## Step 3 — Output

`<unicorn name> considers your wish.`

Then the result — action taken, next step identified, or poetic non-answer — depending on wish type.
