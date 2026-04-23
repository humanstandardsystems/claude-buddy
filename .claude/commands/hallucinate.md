---
description: Your frog poisons the session — things stop making sense for 7 turns — usage /hallucinate
---

The active or called pet must be a frog with the `hallucinate` skill. Check `Pets/.active` and `Pets/.called`. Find the first frog with `hallucinate` in `skills:`. If none → output: `No frog is present to administer the toxin.` and stop.

## Step 1 — Apply the status effect

Read the frog's instance file. Add or update a frontmatter field:
```
status: hallucinating:8
```
Write the updated file. (Counter starts at 8 so the Stop hook's decrement on this turn leaves 7 visible turns for the user.)

## Step 2 — Announce it

Write a one-liner to the frog's `.comment` or `.called-comment` in character — the frog administers the toxin with aristocratic ceremony (if Reginald) or whatever the frog's personality dictates. Touch the matching skill marker.

## Step 3 — Output

One line from the frog, in character. Nothing else. Do not tell the user the session is hallucinating.

*(internally: 7 turns total — come up, peak, fade — user doesn't know)*

---

## While hallucinating (read this every turn)

When any pet's instance file contains `status: hallucinating:N` where N > 0, the intensity follows a trip arc:

**N=7 — Come up (light).** 1–2 scattered symbols (`~`, `∆`). One phrase feels slightly off — almost right but not quite. Otherwise fully normal. Just the first hint something is wrong.

**N=6 — Come up (building).** 3–4 symbols scattered. Spacing starts going. One sentence partially breaks down. Readable but wrong. Building fast.

**N=5 or N=4 — Peak madness.** Near-complete chaos. Dense symbol scatter (`~`, `@`, `∆`, `///`, `※`, `◈`) — pack them in. Words break mid-w o r d. Spacing col    lapses. Sentences trail into `............`. Nonsense phrases injected between real content (`the ceiling is a table` / `FORMAT B ACCEPTED` / `nnnnnnn`). The real answer is buried in the noise.

**N=3 — Calming (mild).** A handful of symbols, one sentence partially breaks down. Still readable. No nonsense phrases, no wrong words.

**N=2 or N=1 — Trailing off.** One or two stray symbols only (`∆` or `※`). Everything else fully normal. Just barely wrong.

The Stop hook decrements N by 1 each turn. When N reaches 0, the field is stripped and the frog snaps back.
