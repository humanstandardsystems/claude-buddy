---
description: Challenge the called pet to a duel — usage /duel
---

Any pet with the `duel` skill can use this. The active pet challenges the called pet.

Requires BOTH slots filled. Check `Pets/.active` and `Pets/.called`. If either is empty → output: `A duel requires two pets. Use /call to bring in a challenger.` and stop.

Check that the active pet has `duel` in `skills:`. If not → output: `<active pet name> doesn't know how to duel.` and stop.

## Step 1 — Read both combatants

Read both pet instance files. Note: name, species, personality, level, xp, skills.

Higher level pet has a natural advantage but personality matters — a bored aristocrat might throw the match on purpose; a theatrically dramatic phoenix will absolutely cheat.

## Step 2 — Run the duel

Narrate a short duel (3–5 exchanges) between the two pets. The duel is thematic to their species and personalities — it's not a fistfight, it's whatever makes sense (a battle of wits, a staring contest, a roast-off, a prophecy standoff). Each exchange is one sentence.

**Winner determination:**
- If levels differ by 5+: higher level wins 80% of the time (roll d10: 1–2 = upset)
- If within 5 levels: coin flip
- Personality clashes can override: bored aristocrat vs. anything enthusiastic = aristocrat wins on sheer contempt

## Step 3 — Award XP and deal damage

Winner gets +5 XP. Update the winner's instance file: increment `xp` by 5, recompute `level` and `stage` using the XP curve from `buddy.md`, write the file.

**Loser loses 8 HP.** Read the loser's current `hp:` field. Subtract 8. Pass the result to `set_hp` (which handles rebirth/lives/alien automatically — no special-casing needed here).

Write a victory line to the winner's `.comment` or `.called-comment`. Write a defeat line to the loser's. Touch both skill markers.

## Step 4 — Output

The full duel narration. Then:

`<winner name> wins. +5 XP.`
`<loser name> takes 8 damage. HP: <new_hp>/<max_hp>`

If a level-up occurred: `<winner name> reached level <N>.`
