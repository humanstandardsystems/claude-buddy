---
description: Boot sequence — run full startup and render a HUD health report
---

You have been invoked as the session boot command. Execute these steps in order. No preamble, no follow-up text.

## Step 1 — Render the HUD

Run this Bash command to open the HUD in a separate Terminal.app window:

```
printf 'printf "\\\\033[8;59;80t"\npython3 .claude/rise.py\nexec bash\n' > /tmp/rise_hud.sh && chmod +x /tmp/rise_hud.sh && open -a Terminal /tmp/rise_hud.sh
```

This writes a temp script, then opens it in Terminal.app with full colors. The `exec bash` keeps the window open after the HUD renders. Do NOT try to process or re-emit the script output — the terminal handles display entirely.

## Step 2 — Absorb governance (silent)

The governance framework is active for this session. You don't need to re-read it as part of `/rise` — the script confirms all 5 docs exist. But you ARE operating under its constraints: no decisions, no resource commitments, no undisclosed inference, human oversight required. Default to most restrictive interpretation when uncertain.

## Step 3 — Buddy auto-resume

If the HUD shows `Status [ACTIVE]` in the BUDDY section, a pet is live. Load `.claude/commands/buddy.md` and follow the **persistent heckling rules (Step 4 onward)** for the rest of this session:

- XP, level, and stage are bumped by the Stop hook automatically — do NOT edit the instance file.
- Write a fresh one-liner to `Pets/.comment` reacting to the boot-up, in the pet's personality. No surrounding quotes.
- `touch Pets/.skill_spoke_active` so the Stop hook skips its Haiku heckle for the boot turn.

If status is `IDLE` or `EXPIRED`, do nothing buddy-related unless the user runs `/buddy`.

## Step 3b — Night shift owl

Run this check silently after buddy auto-resume. Do NOT announce it unless the owl actually spawns.

1. Read `last_seen` from the active pet's instance file (field is `YYYY-MM-DD`).
2. Compare to today's date. If `last_seen` equals today → skip (user already had a session today, owl stays dark).
3. If `last_seen` is before today (overnight gap):
   a. Read `Pets/.called`. If it contains any non-empty slug → skip (left panel occupied, do not displace).
   b. Scan all `.md` files in `Pets/` (top level, no `.`-prefixed, no `.memory.md`) for any pet whose `species:` field is `owl`.
   c. If no owl exists in the collection → skip silently.
   d. If an owl is found: `touch` the owl's instance file (`Pets/<slug>.md`) to refresh its mtime — the statusline rejects pets with files older than 24h and the owl is always dormant between sessions. Then write its slug to `Pets/.called`. Write a night-shift one-liner to `Pets/.called-comment` in the owl's personality — the owl has been up all night, is dry and tired and a little smug about it, makes a vague reference to things being quiet while you were away. Write `2` to `Pets/.night_shift_turns`. Touch `Pets/.skill_spoke_called`.

The owl will auto-dismiss after 2 prompts via the UserPromptSubmit hook. Do not mention the auto-dismiss to the user.

## Step 4 — Done

The boot is complete. Output ONE plain text line after the HUD with the buddy's boot-up heckle (the same one you wrote to `.comment`), if a buddy is active. Otherwise, output nothing.

The session is ready. Wait for user input.
