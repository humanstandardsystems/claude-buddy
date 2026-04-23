#!/usr/bin/env python3
"""Claude Code statusline renderer: active pet (right) + called pet (left)."""
import fcntl
import os
import re
import shutil
import struct
import sys
import termios
import textwrap
import time
from pathlib import Path

PETS = Path(__file__).parent.parent / "Pets"
HALLUCINATE_COLORS = [
    "\x1b[38;2;14;33;201m",    # deep blue
    "\x1b[38;2;243;53;180m",   # hot pink
    "\x1b[38;2;255;232;20m",   # yellow
    "\x1b[38;2;47;209;245m",   # cyan
    "\x1b[38;2;132;33;255m",   # purple
    "\x1b[38;2;41;227;5m",     # green
]
ALIEN_COLORS = [
    "\x1b[38;2;0;255;180m",    # alien aqua
    "\x1b[38;2;57;255;20m",    # neon green
    "\x1b[38;2;75;0;130m",     # deep purple
    "\x1b[38;2;100;255;50m",   # lime
    "\x1b[38;2;0;255;130m",    # seafoam
    "\x1b[38;2;180;255;0m",    # yellow-green
]
RESET   = "\x1b[0m"
ACTIVE_FILE         = PETS / ".active"
CALLED_FILE         = PETS / ".called"
COMMENT_FILE        = PETS / ".comment"
CALLED_COMMENT_FILE = PETS / ".called-comment"
PET_STALE_SECONDS = 24 * 60 * 60

# ── XP / level helpers ────────────────────────────────────────────────────────
TIER_COSTS     = [3, 8, 15, 25, 40]
LEVELS_PER_TIER  = 5
LEVELS_PER_STAGE = LEVELS_PER_TIER * len(TIER_COSTS)
XP_PER_STAGE   = sum(c * LEVELS_PER_TIER for c in TIER_COSTS)
STAGES = ["baby", "adolescent", "adult", "legendary"]


def derive_level(total_xp: int):
    stage_idx = min(total_xp // XP_PER_STAGE, len(STAGES) - 1)
    stage_xp  = total_xp - stage_idx * XP_PER_STAGE
    if stage_idx == len(STAGES) - 1 and stage_xp >= XP_PER_STAGE:
        stage_xp = XP_PER_STAGE - 1
    remaining     = stage_xp
    level_in_stage = 1
    for tier_cost in TIER_COSTS:
        for _ in range(LEVELS_PER_TIER):
            if remaining < tier_cost:
                return stage_idx * LEVELS_PER_STAGE + level_in_stage, STAGES[stage_idx], remaining, tier_cost
            remaining -= tier_cost
            level_in_stage += 1
    return (stage_idx + 1) * LEVELS_PER_STAGE, STAGES[stage_idx], TIER_COSTS[-1], TIER_COSTS[-1]


# ── Pet loader ────────────────────────────────────────────────────────────────
def load_pet(slug: str, stale_file=None, talking: bool = False):
    """Parse a pet file. Returns dict or None. Clears stale_file if pet is stale."""
    f = PETS / f"{slug}.md"
    if not f.exists():
        return None
    if time.time() - f.stat().st_mtime > PET_STALE_SECONDS:
        if stale_file:
            try: stale_file.write_text("")
            except Exception: pass
        return None
    text = f.read_text()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not m:
        return None
    fm_raw, _ = m.groups()
    fm: dict[str, str] = {}
    for line in fm_raw.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    name = fm.get("name", "?")
    xp   = int(fm.get("xp", "0") or "0")
    lvl, stage, xp_in, lvl_cost = derive_level(xp)
    stage_label = stage.capitalize() + " Form"
    art = ""
    species = fm.get("species", "")
    status  = fm.get("status", "")
    species_file = PETS / "species" / (f".{species}.md" if species == "alien" else f"{species}.md")
    body = species_file.read_text() if species_file.exists() else ""
    sec_m = re.search(rf"## {re.escape(stage_label)}\b(.*?)(?=\n## |\Z)", body, re.DOTALL)
    if sec_m:
        section = sec_m.group(1)
        # Split on level 3+ headers, tracking nesting depth
        parts = re.split(r"\n(#{3,6}) (.+?)\n", "\n" + section)
        # parts = [pre, marker1, name1, content1, marker2, name2, content2, ...]
        idle_blocks: list[str]  = []
        blink_blocks: list[str] = []
        flap_blocks: list[str]  = []
        mouth_blocks: list[str] = []
        ganja_blocks: list[str] = []
        sit_blocks:   list[str] = []
        idle_blocks += re.findall(r"```\n(.*?)```", parts[0], re.DOTALL)
        stack: list[tuple[int, str]] = []
        for i in range(1, len(parts), 3):
            level = len(parts[i])
            hname = parts[i + 1].lower()
            content = parts[i + 2] if i + 2 < len(parts) else ""
            while stack and stack[-1][0] >= level:
                stack.pop()
            stack.append((level, hname))
            path   = " ".join(n for _, n in stack)
            blocks = re.findall(r"```\n(.*?)```", content, re.DOTALL)
            if "blink" in path:
                blink_blocks += blocks
            elif "down" in path or "flap" in path:
                flap_blocks += blocks
            elif "mouth" in path or "speak" in path:
                mouth_blocks += blocks
            elif "ganja" in path:
                ganja_blocks += blocks
            elif "sit" in path:
                sit_blocks += blocks
            else:
                idle_blocks += blocks

        # 16-frame cycle at 8fps → punctuation fires ~once every 2s for one frame
        SEQ_LEN, BLINK_FRAME, FLAP_FRAME = 16, 15, 7
        if species == "alien" and idle_blocks:
            # Lock one pose per intervention — chosen at trigger time
            try:
                pose_idx = int((PETS / ".alien-pose").read_text().strip())
            except Exception:
                pose_idx = 0
            if int(time.time()) % 3 == 0 and blink_blocks:
                art = blink_blocks[pose_idx % len(blink_blocks)].rstrip("\n")
            else:
                art = idle_blocks[pose_idx % len(idle_blocks)].rstrip("\n")
        else:
            if "stoned" in status and ganja_blocks:
                idle_blocks = ganja_blocks
            elif "sitting" in status and sit_blocks:
                idle_blocks = sit_blocks
            frame = int(time.time() * 8) % SEQ_LEN
            pool = idle_blocks
            if frame == BLINK_FRAME and blink_blocks:
                pool = blink_blocks
            elif frame == FLAP_FRAME and flap_blocks:
                pool = flap_blocks
            elif talking and mouth_blocks:
                pool = mouth_blocks if (frame // 2) % 2 == 0 else (idle_blocks or mouth_blocks)
            if not pool:
                pool = idle_blocks or mouth_blocks or blink_blocks or flap_blocks
            if pool:
                art = pool[int(time.time() * 8) % len(pool)].rstrip("\n")
    name_label = f" {name} "
    lv_text    = f" Lv {lvl} · XP {xp_in}/{lvl_cost} "
    st_text    = f" {stage} form "
    if species == "alien":
        lv_text = " Lv ∞ · XP ∞/∞ "
        st_text = " 6th density form "
    status     = fm.get("status", "")
    species_val = fm.get("species", "")
    stage_max_hp = {"baby": 10, "adolescent": 15, "adult": 20, "legendary": 25}
    max_hp   = stage_max_hp.get(stage, 10)
    hp_raw   = fm.get("hp", "")
    hp       = int(hp_raw) if str(hp_raw).isdigit() else max_hp
    hp       = min(hp, max_hp)
    BAR_W    = 8
    filled  = round(hp / max_hp * BAR_W) if max_hp > 0 else 0
    hp_bar  = "█" * filled + "░" * (BAR_W - filled)
    lives_raw = fm.get("lives", "")
    if species_val == "cat" and str(lives_raw).isdigit():
        hp_text = f" HP {hp_bar} {hp}/{max_hp} ◆{lives_raw} "
    else:
        hp_text = f" HP {hp_bar} {hp}/{max_hp} "
    inner_w    = max(len(name_label), len(lv_text), len(st_text), len(hp_text), 22)
    return dict(name_label=name_label, lv_text=lv_text, st_text=st_text,
                hp_text=hp_text, inner_w=inner_w, art_lines=art.splitlines(), status=status,
                species=species)


# ── Speech bubble builder ─────────────────────────────────────────────────────
def build_bubble(text: str, inner_w: int = 28) -> list[str]:
    """Word-wrap text into a speech bubble box. Lines have no ANSI."""
    if not text:
        return []
    text_lines: list[str] = []
    cur = ""
    for word in text.split():
        if not cur:
            cur = word
        elif len(cur) + 1 + len(word) <= inner_w:
            cur = cur + " " + word
        else:
            text_lines.append(cur)
            cur = word
    if cur:
        text_lines.append(cur)
    actual_w = max(inner_w, max((len(tl) for tl in text_lines), default=0))
    border = "-" * (actual_w + 2)
    lines = [f".{border}."]
    for tl in text_lines:
        lines.append(f"| {tl}{' ' * (actual_w - len(tl))} |")
    lines.append(f"`{border}'")
    return lines


# ── Block builder ─────────────────────────────────────────────────────────────
def build_lines(pet: dict, comment: str = "", max_comment_w: int = 50) -> list[str]:
    """Return plain content strings for a pet block (no positioning)."""
    name_label = pet["name_label"]
    lv_text    = pet["lv_text"]
    st_text    = pet["st_text"]
    hp_text    = pet["hp_text"]
    inner_w    = pet["inner_w"]
    art_lines  = pet["art_lines"]

    def pad_row(s: str) -> str:
        return f"│{s}{' ' * (inner_w - len(s))}│"

    dashes = inner_w - len(name_label)
    l, r   = dashes // 2, dashes - dashes // 2
    frame  = [
        f" ╭{'─' * l}{name_label}{'─' * r}╮",
        f"╭{pad_row(lv_text.rstrip())}",
        f"│{pad_row(st_text.rstrip())}",
        f"│{pad_row(hp_text.rstrip())}",
        f"│╰{'─' * inner_w}╯",
        f"╰{'─' * inner_w}╯",
    ]
    lines = frame + art_lines
    if comment:
        wrap_width = max(inner_w + 2, min(max_comment_w, 70))
        if '\n' in comment:
            wrapped = [l for l in comment.split('\n') if l.strip()]
        else:
            wrapped = textwrap.wrap(comment, width=max(wrap_width - 2, 10))
        for i, wline in enumerate(wrapped):
            prefix = '"' if i == 0 else ' '
            suffix = '"' if i == len(wrapped) - 1 else ''
            lines.append(prefix + wline + suffix)
    return lines


# ── Terminal width ────────────────────────────────────────────────────────────
def detect_width() -> int:
    env_cols = os.environ.get("COLUMNS")
    if env_cols and env_cols.isdigit():
        return int(env_cols)
    try:
        with open("/dev/tty") as tty:
            packed = fcntl.ioctl(tty, termios.TIOCGWINSZ, b"\0" * 8)
            _, cols, _, _ = struct.unpack("hhhh", packed)
            if cols > 0:
                return cols
    except Exception:
        pass
    return shutil.get_terminal_size(fallback=(120, 24)).columns


# ── Main ──────────────────────────────────────────────────────────────────────
try:
    sys.stdin.read()
except Exception:
    pass

active_slug    = ACTIVE_FILE.read_text().strip()         if ACTIVE_FILE.exists()         else ""
called_slug    = CALLED_FILE.read_text().strip()         if CALLED_FILE.exists()         else ""
comment        = COMMENT_FILE.read_text().strip()        if COMMENT_FILE.exists()        else ""
called_comment = CALLED_COMMENT_FILE.read_text().strip() if CALLED_COMMENT_FILE.exists() else ""

TALKING_WINDOW = 4.0  # seconds — mouth animates only briefly after a fresh comment
def _is_fresh(p: Path) -> bool:
    return p.exists() and (time.time() - p.stat().st_mtime) < TALKING_WINDOW
active_talking = bool(comment)        and _is_fresh(COMMENT_FILE)
called_talking = bool(called_comment) and _is_fresh(CALLED_COMMENT_FILE)

if not active_slug and not called_slug:
    sys.exit(0)

width  = detect_width()
target = max(width - 30, 1)
ZWNJ   = "\u200c"

DIAG = os.environ.get("STATUSLINE_DIAG") == "1" or Path("/tmp/statusline-diag").exists()
if DIAG:
    nbsp = "\u00a0"
    esc  = "\x1b"
    print(f"L[{' '*20}]20sp[{' '*50}]50sp[{nbsp*20}]20nbsp[{nbsp*50}]50nbsp"
          f"{esc}[20CCUF20{esc}[50CCUF50END")
    sys.exit(0)

# ── Right block: active pet ───────────────────────────────────────────────────
# List of (pad_n, content) tuples — pad_n spaces precede content from col 0
right_items: list[tuple[int, str]] = []

if active_slug:
    pet = load_pet(active_slug, stale_file=ACTIVE_FILE, talking=active_talking)
    if pet:
        frame_w      = pet["inner_w"] + 3
        art_lines    = pet["art_lines"]
        hallucinating = "hallucinating" in pet.get("status", "")
        art_max_w    = max((len(l) for l in art_lines), default=0)
        n_art        = len(art_lines)

        BUBBLE_INNER = 28
        BUBBLE_BOX_W = BUBBLE_INNER + 4
        BUBBLE_GAP   = 3

        bubble_lines = build_bubble(comment, inner_w=BUBBLE_INNER) if comment else []
        n_bubble = len(bubble_lines)

        bubble_start = (n_art - n_bubble) // 2 if 0 < n_bubble < n_art else 0
        if bubble_start < 0:
            bubble_start = 0
        connector_bi = (1 + (n_bubble - 2)) // 2 if n_bubble > 2 else -1

        # Compute block_pad first so frame header aligns with art, not independently
        if n_bubble > 0:
            block_pad = max(0, target - (BUBBLE_BOX_W + BUBBLE_GAP + art_max_w))
            frame_pad = block_pad + BUBBLE_BOX_W + BUBBLE_GAP
        else:
            block_pad = max(0, target - art_max_w)
            frame_pad = block_pad

        hallucinate_offset = int(time.time() * 3) % len(HALLUCINATE_COLORS)
        alien_offset   = int(time.time() * 3) % len(ALIEN_COLORS)
        is_alien = pet.get("species") == "alien"

        for j, line in enumerate(build_lines(pet, "")[:6]):
            if hallucinating:
                line = HALLUCINATE_COLORS[(j + hallucinate_offset) % len(HALLUCINATE_COLORS)] + line + RESET
            elif is_alien:
                line = ALIEN_COLORS[(j + alien_offset) % len(ALIEN_COLORS)] + line + RESET
            right_items.append((frame_pad, line))

        if n_bubble > 0:
            block_pad = max(0, target - (BUBBLE_BOX_W + BUBBLE_GAP + art_max_w))
            n_total   = max(n_art, n_bubble + bubble_start)
            for i in range(n_total):
                art_line = art_lines[i] if i < n_art else " " * art_max_w
                if hallucinating and i < n_art:
                    art_line = HALLUCINATE_COLORS[(i + hallucinate_offset) % len(HALLUCINATE_COLORS)] + art_line + RESET
                elif is_alien and i < n_art:
                    art_line = ALIEN_COLORS[(i + alien_offset) % len(ALIEN_COLORS)] + art_line + RESET

                bi = i - bubble_start
                if 0 <= bi < n_bubble:
                    connector = "-- " if bi == connector_bi else "   "
                    bline = bubble_lines[bi]
                    if hallucinating:
                        bline = HALLUCINATE_COLORS[(bi + hallucinate_offset) % len(HALLUCINATE_COLORS)] + bline + RESET
                    elif is_alien:
                        bline = ALIEN_COLORS[(bi + alien_offset) % len(ALIEN_COLORS)] + bline + RESET

                    composite = bline + connector + art_line
                else:
                    composite = " " * (BUBBLE_BOX_W + BUBBLE_GAP) + art_line
                right_items.append((block_pad, composite))
        else:
            art_pad = max(0, target - art_max_w)
            for i, line in enumerate(art_lines):
                if hallucinating:
                    line = HALLUCINATE_COLORS[(i + hallucinate_offset) % len(HALLUCINATE_COLORS)] + line + RESET
                elif is_alien:
                    line = ALIEN_COLORS[(i + alien_offset) % len(ALIEN_COLORS)] + line + RESET
                right_items.append((art_pad, line))

# ── Left block: called pet ────────────────────────────────────────────────────
# Plain content strings — left-aligned at column 0
left_lines: list[str] = []

if called_slug and called_slug != active_slug:
    pet = load_pet(called_slug, stale_file=CALLED_FILE, talking=called_talking)
    if pet:
        # Cap left comment width so it never overlaps the right block
        if right_items:
            min_right_pad = min(p for p, _ in right_items)
            safe_left_w = max(10, min_right_pad - 2)
        else:
            safe_left_w = 50
        left_lines = build_lines(pet, called_comment, max_comment_w=safe_left_w)
        if pet.get("species") == "alien":
            alien_offset = int(time.time() * 3) % len(ALIEN_COLORS)
            left_lines = [
                ALIEN_COLORS[(i + alien_offset) % len(ALIEN_COLORS)] + line + RESET
                for i, line in enumerate(left_lines)
            ]

# ── Merge and print ───────────────────────────────────────────────────────────
n = max(len(left_lines), len(right_items))
output: list[str] = []
for i in range(n):
    lc = left_lines[i]   if i < len(left_lines)  else ""
    if i < len(right_items):
        pad_n, rc = right_items[i]
    else:
        pad_n, rc = target, ""
    gap = max(0, pad_n - len(re.sub(r'\x1b\[[0-9;]*m', '', lc)))
    output.append(ZWNJ + lc + " " * gap + rc)

print("\n".join(output))
