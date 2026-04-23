---
description: Have your cow bless the work — finds what's genuinely going well — usage /bless
---

The active or called pet must be a cow with the `bless` skill. Check `Pets/.active` and `Pets/.called`. Find the first cow with `bless` in `skills:`. If none → output: `No sacred cow is present to bestow a blessing.` and stop.

## Step 1 — Find what is good

Read the 3–5 most recently modified files in the current working directory (excluding `Pets/`, `.claude/`, `node_modules/`, `.git/`). Look for genuine strengths:
- Clear, well-named functions
- Good test coverage where it exists
- Consistent patterns
- Simple solutions to what could have been complex
- Clean separation of concerns

Be honest. Do not manufacture praise. If nothing stands out, say so with grace.

## Step 2 — Bestow the blessing

Write 2–3 sentences to `.comment` or `.called-comment` in the cow's personality: serene, unhurried, sacred-feeling. The cow names the specific good things with reverence, as if acknowledging something holy. Not hype — genuine recognition. Touch the matching skill marker.

## Step 3 — Output

`<cow name> has blessed this work.`

Then the blessing verbatim.
