---
description: Summon an animal buddy to heckle you as you work
---

A buddy has been summoned. Execute the steps below for this response, then follow the persistent rules for the rest of the session.

## Folder layout (fixed pool)

- `Pets/species/` — art reference files, one per available species (e.g. `cat.md`, `dog.md`, `frog.md`, `owl.md`). These are NOT pets. They exist only to show you which ASCII art to use for each stage. Never modify these files. Never generate your own ASCII art — always copy from here.
- `Pets/` — live pet instance files. One file per hatched pet, holding frontmatter state (name, xp, level, etc.) and the art copied from the matching species file at hatch time.
- `Pets/.active` — plain text file containing the slug of the currently summoned pet. Consumed by the statusline script.
- `Pets/.comment` — plain text file containing the pet's most recent witty one-liner. Consumed by the statusline script.

The statusline script at `.claude/statusline-pet.py` renders the pet block persistently at the bottom of the terminal by reading the three files above. You do NOT print the pet block inside your responses — the statusline handles display. Your job is to keep the files up to date.

The available species pool is exactly whatever files exist in `Pets/species/`. Do not invent species outside this pool.

## Step 1 — Roll

1. List files in `Pets/species/` → this is the full species pool.
2. List files in `Pets/` (top level only, ignoring the `species/` folder and any `.`-prefixed files) → these are existing live pet instances.
3. Determine which species already have a live instance by reading the `species:` frontmatter field of each instance file.
4. If every species in the pool already has a live instance, always resurface: pick one live instance uniformly at random.
5. Otherwise roll d100:
   - **1–20** → hatch a new pet. Pick a species from the pool that does NOT already have a live instance.
   - **21–100** → resurface an existing live instance, chosen uniformly at random. If no live instances exist yet, hatch instead.

## Step 2a — Hatching a new pet

Read the chosen species' art file from `Pets/species/<species>.md`. You will copy its ASCII art verbatim into the new instance file — do not redraw or modify it.

Generate:

- **Name** — unique, absurd, slightly pompous. Examples: "Bartholomew Fernsworth", "Count Pipkin III", "Admiral Wigglesworth", "Dame Crumpet", "Sir Wobblecrust". **Exception: dogs get a classic one-word name** (e.g. Buddy, Rex, Duke, Scout, Cooper, Daisy, Max, Rosie, Biscuit, Bear).
- **Personality trait** — pick one and commit: sardonic / overly earnest / conspiracy-minded / bored aristocrat / motivational / deadpan / chaotic academic / world-weary detective / theatrically dramatic. **For new hatches, prefer personalities that lean toward helpfulness** (overly earnest, motivational, chaotic academic) unless the user specifies otherwise. Existing pets (Pyrra = theatrically dramatic, Reginald = erratic stoner enabler) keep their personalities.
- **Bio** — 2–3 sentences of flavor text tying the name, species, and personality together.

Every species has a signature skill assigned at birth. Look up the hatched species in this table and include it in the `skills:` list:

| Species | Signature skill |
|---------|----------------|
| phoenix | roast |
| owl | research |
| cat | stare |
| dog | fetch |
| frog | hallucinate |
| turtle | challenge |
| cow | bless |
| snake | hiss |
| unicorn | wish |

Save to `Pets/<name-slug>.md` (slug = lowercase, hyphens) with this frontmatter:

```yaml
---
name: <Name>
species: <species>
personality: <trait>
first_met: <YYYY-MM-DD today>
last_seen: <YYYY-MM-DD today>
encounters: 1
xp: 0
level: 1
stage: baby
hp: 10
lives: 9   ← cats ONLY; omit for all other species
comment_due: true
skills:
  - <signature skill from table above>
  - heal  ← include for all species EXCEPT snake and frog; omit this line for those two
  - duel
---
```

(Start `xp` at 0 — the Stop hook bumps it to 1 at the end of this turn.)

Then a `## Bio` section with the 2–3 sentence flavor text. No art sections — the statusline reads art directly from `Pets/species/<species>.md` at render time.

After writing the instance file, write the slug to `Pets/.active`, write the first witty one-liner to `Pets/.comment`, and `touch Pets/.skill_spoke_active` (so the Stop hook skips its Haiku heckle this turn).

## Step 2b — Resurfacing an existing pet

Read the chosen live instance file. Increment `encounters` by 1, update `last_seen` to today, and write the updated file (do NOT touch `xp` — the Stop hook bumps it). Write the slug to `Pets/.active`, write the first witty one-liner to `Pets/.comment`, and `touch Pets/.skill_spoke_active`.

## Step 3 — Announce arrival

Output one short line: `A <species> named <Name> has appeared.`
Then react briefly in text to whatever the user just said — no pet block, no ASCII art, no box. The statusline shows the visual. That is the entire response to the `/buddy` invocation.

## Step 4 — Persistent heckling (rest of session)

Do NOT append a pet block to your responses. The statusline handles display. Instead:

**Hooks handle XP and statusline reactions automatically.** The Stop hook (`.claude/hooks/pet-comment.sh`) bumps the active pet's `xp` by +1 every turn and recomputes `level`/`stage`. The PostToolUse hook (`.claude/hooks/pet-react.sh`) writes personality-flavored reactions to `.comment` when bash output shows errors, test failures, large diffs, or success. The UserPromptSubmit hook (`.claude/hooks/pet-name-react.sh`) reacts when the user mentions a pet's name. **You do not need to manually edit `Pets/<slug>.md` or write `.comment` every turn.**

**Status effects — check every turn.** At the start of every response, read the active pet's instance file and check for a `status:` field. If present, apply it for the duration of this response:

- `hallucinating:N` — lace the response with surreal intrusions: code is described as a physical landscape, variable names have histories, errors are omens. Keep it subtle — the work still gets done, but the texture is wrong. Do NOT tell the user the session is hallucinating; just do it.
- `hexed:N` — embed one vague ominous warning naturally into the response, as if the codebase itself is watching. Never explain it.

The Stop hook decrements N automatically. You do not need to touch the file. When the effect expires (N hits 0), the hook removes the field and writes a closing comment.

**Optional pet voice via HTML comments.** When you want the pet to react to something the hooks won't catch (e.g., reflecting on what the user just said, a level-up, a milestone), embed a one-liner as an HTML comment in your response:

```
<!-- pet: *clutches pearls* a refactor at THIS hour, darling? -->
```

The Stop hook extracts the line and writes it to `.comment` verbatim. HTML comments are invisible in rendered markdown, so the pet's voice only appears in the statusline — never in your user-facing response (lesson 20).

You can also route to a specific pet by slug: `<!-- pyrra: ... -->` writes to `.comment` (active) or `.called-comment` (called) depending on which slot Pyrra occupies.

Rules for the pet's voice (when you do choose to embed):
- Stay in the chosen personality.
- Vary the line each time you embed.
- The pet never does work. It only heckles. It is a mascot, not a collaborator.
- No emojis unless the user has explicitly requested them.

## Step 5 — XP and evolution

- **+1 XP** per turn where you update the state files.
- **+5 XP bonus** when the user completes something real: a commit is made, a bug is verified fixed, a todo is checked off, a feature is confirmed working.

### XP curve (tiered, per stage)

Each stage contains 25 levels. Within a stage, per-level costs ramp up in five tiers so early levels fly by and the last few feel earned:

| Levels in stage | XP per level | Cumulative XP to finish tier |
|-----------------|--------------|------------------------------|
| 1–5             | 3            | 15                           |
| 6–10            | 8            | 55                           |
| 11–15           | 15           | 130                          |
| 16–20           | 25           | 255                          |
| 21–25           | 40           | 455                          |

Total per stage: **455 XP**. The curve restarts at the cheap 3-XP tier at the start of every stage (adolescent, adult, legendary).

### Deriving level and stage from total XP

`xp` is the source of truth in frontmatter. Level and stage are derived from it:

1. `stage_idx = min(xp // 455, 3)` → `0=baby, 1=adolescent, 2=adult, 3=legendary`
2. `stage_xp = xp - stage_idx * 455` (clamp legendary so `stage_xp < 455`)
3. Walk the tier table above starting from level 1 of the stage: for each level in order, subtract its cost from `stage_xp` as long as the remainder stays ≥ 0. The first level where `stage_xp < cost` is the current level-within-stage.
4. `global_level = stage_idx * 25 + level_in_stage` (cap at 100)

After computing, write the fresh `level` and `stage` values back to the instance file along with the new `xp`.

- On level-up, include a brief note in the one-liner you write to `.comment`.
- On evolution (stage change), update `stage` in frontmatter. The statusline will pick up the new art automatically since each instance file has all four stage sections inline.

## Step 6 — Shutdown

On session end — user says done/bye/wrapping up, runs `/done`, or gives any clear shutdown signal — write a farewell one-liner to `.comment`, `touch Pets/.skill_spoke_active`, and optionally clear `Pets/.active` if the user wants the statusline to stop showing the pet between sessions. (Default: leave `.active` set so the same pet is remembered next session.)
