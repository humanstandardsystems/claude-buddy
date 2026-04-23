---
description: Feed a food item to your active pet — usage /feed [item|number] [Nx]
---

## Step 1 — Check for active buddy

Read `Pets/.active`. If empty → output: `No active buddy. Run /buddy to summon one.` and stop.

Read the active pet's instance file. Get `name`, `species`, `personality`, `stage`, `hp`.

Determine `max_hp` from stage: baby=10, adolescent=15, adult=20, legendary=25.

## Step 2 — Show inventory if no item specified

If `$ARGUMENTS` is blank, read `Pets/inventory.md` and display it:

```
Inventory:
  1. kibble  x<n>
  2. berry   x<n>
  3. treat   x<n>
  4. steak   x<n>
  5. potion  x<n>
```

Then: `Use /feed <item|number> [Nx] to feed your pet. Examples: /feed kibble, /feed 1, /feed 1 3x`

Stop here.

## Step 3 — Validate item and quantity

Split `$ARGUMENTS` into words. First word = item selector. Second word (optional) = quantity, parsed as `Nx` (e.g. `2x` → 2, `3x` → 3). If no second word, quantity = 1.

Resolve item: if the first word is a number 1–5, map it:
`1=kibble, 2=berry, 3=treat, 4=steak, 5=potion`

Valid item names: `kibble`, `berry`, `treat`, `steak`, `potion`.

If item is unknown → output: `Unknown item. Valid items: kibble, berry, treat, steak, potion.` and stop.

Read `Pets/inventory.md`. If that item's count is 0 → output: `No <item> in inventory.` and stop.

Clamp quantity to available stock: `actual_qty = min(quantity, inventory_count)`. If `actual_qty < quantity`, note that stock ran short.

## Step 4 — Feed the pet

**HP restoration per item:**
| Item | HP restored |
|------|-------------|
| kibble | 1 |
| berry | 3 |
| treat | 5 |
| steak | 8 |
| potion | Full heal (max_hp) |

For phoenix: always full HP (∞), but still consume the item.

Compute total restoration: `restore * actual_qty`. For potion: each use = full heal, so one potion sets to max_hp regardless of quantity.

Compute new HP: `min(current_hp + total_restore, max_hp)`. For phoenix: always max_hp.

Write new `hp:` back to the pet's instance file.

Decrement the item count in `Pets/inventory.md` by `actual_qty` (floor at 0).

Write a one-liner to `Pets/.comment` in the active pet's personality, reacting to being fed (gratitude, indifference, excitement — stay in character). Touch `Pets/.skill_spoke_active`.

## Step 5 — Output

If `actual_qty` = 1: `<pet name> ate the <item>.`
If `actual_qty` > 1: `<pet name> ate <actual_qty>x <item>.`
If stock ran short: append `(only <actual_qty> in stock)`

`HP: <old_hp> → <new_hp>/<max_hp>`

If already at max HP before feeding: `<pet name> is already at full health. (<item> consumed anyway.)`
