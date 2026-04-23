# claude-buddy

A persistent animal companion system for [Claude Code](https://claude.ai/code). Summon a pet that lives in your terminal statusline, heckles you while you work, gains XP, evolves across four stages, and develops its own personality and memory.

## What it does

- **`/buddy`** — roll a random animal companion (cat, dog, frog, owl, phoenix, and more)
- **`/chat <message>`** — talk to your pet; it remembers what you've said across sessions
- **`/call <name>`** — pin a pet to the left statusline panel
- **`/roast [target]`** — have your pet deliver a theatrical roast
- **`/research <topic>`** — send your owl out for a real web answer
- **`/duel`** — challenge the called pet to a duel
- **`/feed`, `/hunt`, `/heal`, `/hiss`, `/hallucinate`, `/ganja`** — and more

Pets gain XP every turn, level up through four stages (baby → adolescent → adult → legendary), and react in real time via a terminal statusline script. The hook system uses Claude Haiku to generate personality-driven heckles based on what actually happened in your session.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- Python 3 (for statusline and HUD renderer)
- macOS (statusline uses terminal escape sequences; Linux support untested)

## Setup

### 1. Clone into your project

```bash
git clone https://github.com/humanstandardsystems/claude-buddy.git
cd your-project
cp -r /path/to/claude-buddy/.claude .
cp -r /path/to/claude-buddy/Pets .
```

Or clone directly as your project root if you want a standalone buddy environment.

### 2. Set your name (optional)

The pet uses `User` by default when generating heckles. Set your name so heckles feel personal:

```bash
export PET_USER_NAME="YourName"
```

Add it to your shell profile (`~/.zshrc` or `~/.bashrc`) to persist.

### 3. Wire up the statusline (optional but recommended)

Add to your terminal profile or shell startup:

```bash
python3 /path/to/your/project/.claude/statusline-pet.py
```

The statusline renders your active pet in the bottom panel of the terminal. Without it, the system still works — you just won't see the live pet display.

### 4. Start Claude Code and summon a pet

```bash
claude
/buddy
```

## File layout

```
.claude/
  commands/       # slash command definitions (buddy, chat, call, roast, ...)
  hooks/          # shell hooks for XP, reactions, and memory
  skills/done/    # session shutdown skill
  statusline-pet.py   # terminal statusline renderer
  rise.py             # HUD dashboard renderer
  settings.json       # Claude Code permissions and hook config

Pets/
  species/        # ASCII art reference files — one per species
  inventory.md    # item inventory (used by hunt, feed, etc.)
```

Live pet instance files (`Pets/<name>.md`) and memory files (`Pets/<name>.memory.md`) are created when you hatch pets. These are gitignored by default — they're yours.

## Species

| Species  | Signature skill |
|----------|----------------|
| phoenix  | roast          |
| owl      | research       |
| cat      | stare          |
| dog      | fetch          |
| frog     | hallucinate    |
| turtle   | challenge      |
| cow      | bless          |
| snake    | hiss           |
| unicorn  | wish           |

## License

MIT
