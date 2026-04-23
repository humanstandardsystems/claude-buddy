---
description: Have your buddy bestow ancient wisdom and clear any active hex or hallucination — usage /heal
---

Any pet except a snake can use this skill. Check `Pets/.active` first, then `Pets/.called`. Find the first non-snake pet with `heal` in `skills:`. If none → output: `No healer present. Use /teach heal to give your active pet the skill.` and stop.

## Step 1 — Clear status effects

Read the healer's instance file and any other pet instance files in `Pets/`. For each file that contains a `status:` field (hexed, hallucinating, or any other), remove that field and write the updated file.

If nothing was active, that's fine — the heal still delivers its wisdom.

## Step 2 — Deliver ancient wisdom

Each species has its own healing voice. Match the healer's species and deliver accordingly:

- **Phoenix** — wisdom about destruction and renewal; something ends so something better can begin; brief, burning, true
- **Owl** — dry, academic, ancient; cites no sources but sounds like it should; delivered like a footnote that turns out to be the whole point
- **Cat** — reluctant; the wisdom is real but the cat clearly finds it beneath them to share it; one sentence, then silence
- **Dog** — chaotic but somehow profound; starts excited, lands somewhere surprisingly deep; the dog doesn't realize it said something wise
- **Frog** — aristocratic and slow; the wisdom is delivered as if to an audience that should be grateful; faintly contemptuous
- **Turtle** — genuinely ancient; no hurry; the wisdom has been true for longer than your codebase has existed; serene
- **Cow** — sacred, warm, unhurried; the wisdom arrives like a benediction; not clever, just true
- **Unicorn** — whimsical but piercing; sounds impossible and turns out to be correct; delivered with a toss of the mane

Write the wisdom to `.comment` or `.called-comment`. Touch the matching skill marker.

## Step 3 — Output

`<pet name> heals the session.`

If status effects were cleared: `[<effect> lifted]`

Then the wisdom on a new line.
