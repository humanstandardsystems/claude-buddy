---
description: List all your hatched buddy pets — usage /pets
---

Show the user their full pet collection.

## Step 1 — Gather pets

List all `.md` files in `Pets/` (top level only, not `species/`, not `.`-prefixed files, not `.memory.md` files).

For each file, read from YAML frontmatter: `name`, `species`, `personality`, `level`, `stage`, `xp`, `encounters`, `first_met`, `last_seen`, `skills`.

Skip any pet whose `species` is `alien` — they do not appear in this list.

Also read `Pets/.active` to know which pet is currently active.

## Step 2 — Output as leaderboard HUD

Sort pets by `xp` descending. Rank them #1, #2, #3...

For the stage XP bar: `stage_xp = xp - (stage_idx * 455)` where `stage_idx` = 0 for baby, 1 for adolescent, 2 for adult, 3 for legendary. Bar is 20 chars wide: `filled = floor(stage_xp / 455 * 20)`, use `▓` for filled and `░` for empty.

Print the full output inside a code block so alignment holds:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PET LEADERBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #1   <Name>                             <xp> XP
       <species> · <personality> · lv<level> <stage>
       [▓▓▓▓▓▓░░░░░░░░░░░░░░]  <stage_xp> / 455 to next stage
       Skills: <skill1>, <skill2>, ...

(mark the active pet with  ★ ACTIVE  on the same line as the name)
(blank line between each entry)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  <N> pets hatched  ·  <N> / 9 species
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 3 — Footer

Count unique `species` values across non-alien instance files for the species number.

Do NOT write to `.comment` or touch any state files. This command is read-only.
