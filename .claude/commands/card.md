---
description: Show the active buddy's XP, level, and progress — usage /card
---

Show a detailed stat card for the currently active pet.

## Step 1 — Read state

Read `Pets/.active` for the active slug. If empty → output: `No active buddy. Run /buddy to summon one.` and stop.

Read the active pet's instance file: `name`, `species`, `personality`, `level`, `stage`, `xp`, `encounters`, `first_met`, `last_seen`, `skills`.

## Step 2 — Compute progress

Use the XP curve from `buddy.md` to determine:

- **stage_idx** = min(xp // 455, 3) → 0=baby, 1=adolescent, 2=adult, 3=legendary
- **stage_xp** = xp − (stage_idx × 455), clamped so stage_xp < 455
- Walk the tier table (levels 1–5 cost 3 XP each, 6–10 cost 8, 11–15 cost 15, 16–20 cost 25, 21–25 cost 40) to find:
  - **level_in_stage** — current level within the stage (1–25)
  - **xp_into_level** — how much XP into the current level
  - **xp_needed** — total XP cost of the current level

Build a progress bar (20 chars wide):
`[████████░░░░░░░░░░░░]`  filled = floor(xp_into_level / xp_needed × 20)

XP to next level = xp_needed − xp_into_level

## Step 3 — Output

Print a clean stat card:

```
<Name>  (<species> · <personality>)

  Stage:    <stage> (stage <stage_idx+1> of 4)
  Level:    <level_in_stage> / 25  (global lv<global_level>)
  XP:       <xp_into_level> / <xp_needed>  [████████░░░░░░░░░░░░]
            <xp_to_next> XP to next level
  Lifetime: <xp> / 1820 XP  [████░░░░░░░░░░░░░░░░]  ← filled = floor(xp / 1820 × 20)

  Encounters:  <encounters>
  First met:   <first_met>
  Last seen:   <last_seen>

  Skills:  <skill1>, <skill2> ...  (or "none unlocked")
```

## Step 4 — Pet reacts

Write a one-liner to `Pets/.comment` in the active pet's personality, reacting to having their stats displayed (vanity, indifference, suspicion — stay in character). Then `touch Pets/.skill_spoke_active`.
