#!/usr/bin/env python3
"""/rise HUD renderer — reads state files and prints a colored system report."""
import re
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent

# ANSI color codes
C  = "\033[96m"    # cyan frame
R  = "\033[0m"     # reset
BW = "\033[1;97m"  # bold white title
Y  = "\033[93m"    # bright yellow
W  = "\033[97m"    # white label
G  = "\033[92m"    # green filled meter
DG = "\033[90m"    # dark gray empty meter
V  = "\033[36m"    # cyan values
BG = "\033[1;92m"  # bold green badge
BR = "\033[1;91m"  # bold red
BY = "\033[1;33m"  # bold yellow (SCRIPTS)
BB = "\033[1;34m"  # bold blue (TASKS)
BM = "\033[1;35m"  # bold magenta (LAST SESSION)
# Rainbow BUDDY letters
RR = "\033[91m"; RYel = "\033[93m"; RG = "\033[92m"; RC = "\033[96m"; RM = "\033[95m"

IW = 68  # inner width between ║ borders
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def vlen(s: str) -> int:
    return len(ANSI_RE.sub("", s))


def line(content: str) -> str:
    pad = max(0, IW - vlen(content))
    return f"{C}║{R}{content}{' ' * pad}{C}║{R}"


def divider(label: str, plain: str) -> str:
    llen = 3 + len(plain) + 1  # "══ " + label + " "
    rlen = max(0, IW - llen)
    return f"{C}╠══ {R}{label}{R} {C}{'═' * rlen}╣{R}"


def meter(filled: int, total: int = 20) -> str:
    f = max(0, min(filled, total))
    e = total - f
    return f"{G}{'█' * f}{R}{DG}{'░' * e}{R}"


MD_RE = re.compile(r"\*\*|\*|`")


def first_nonempty(text: str) -> str:
    for raw in text.splitlines():
        s = raw.strip()
        if s and not s.startswith("#"):
            return MD_RE.sub("", s.lstrip("- ").strip())
    return ""


def fit(prefix_vlen: int, value: str) -> str:
    avail = IW - prefix_vlen - 2
    return value if len(value) <= avail else value[: avail - 1] + "…"


def wrap_box(text: str, prefix_plain: str = "", prefix_colored: str = "") -> list:
    """Wrap text into multiple box lines, aligning continuations under text start."""
    pl = len(prefix_plain)
    avail = IW - 2 - pl  # "  " leading indent + prefix
    indent = "  " + " " * pl

    words = text.split()
    segments, current, length = [], [], 0
    for w in words:
        add = (1 if current else 0) + len(w)
        if current and length + add > avail:
            segments.append(" ".join(current))
            current, length = [w], len(w)
        else:
            current.append(w)
            length += add
    if current:
        segments.append(" ".join(current))

    result = []
    for i, seg in enumerate(segments):
        if i == 0:
            result.append(line(f"  {prefix_colored}{V}{seg}{R}"))
        else:
            result.append(line(f"{indent}{V}{seg}{R}"))
    return result or [line(f"  {prefix_colored}{R}")]


# === Governance ===
gov_files = [
    "_governance/foundation_v1_3.md",
    "_governance/enforcement_layer_v1.md",
    "_governance/interpretations_v1_3.md",
    "_governance/policy_v1_3.md",
    "_governance/README.md",
]
gov_loaded = sum(1 for f in gov_files if (ROOT / f).exists())

# === Lessons ===
lesson_count = 0
lessons_file = ROOT / ".claude/tasks/lessons.md"
if lessons_file.exists():
    for ln in lessons_file.read_text().splitlines():
        if re.match(r"^\| \d{4}-\d{2}-\d{2}", ln):
            lesson_count += 1

# === Todo ===
in_progress = completed = backlog = 0
todo_file = ROOT / ".claude/tasks/todo.md"
if todo_file.exists():
    section = None
    for ln in todo_file.read_text().splitlines():
        if ln.startswith("## In Progress"):
            section = "ip"
        elif ln.startswith("## Completed"):
            section = "c"
        elif ln.startswith("## Backlog"):
            section = "bl"
        elif re.match(r"^\s*-\s+\[x\]", ln):
            completed += 1
        elif re.match(r"^\s*-\s+\[\s*\]", ln):
            if section == "ip":
                in_progress += 1
            elif section == "bl":
                backlog += 1

# === Primer ===
summary = next_step = blockers_text = tech_stack = ""
blocker_count = 0
primer_file = ROOT / ".claude/primer.md"
if primer_file.exists():
    text = primer_file.read_text()
    for header, target in [
        ("Session Summary", "summary"),
        ("Exact Next Step", "next_step"),
        ("Open Blockers", "blockers_text"),
        ("Tech Stack", "tech_stack"),
    ]:
        m = re.search(rf"## {header}\n(.+?)(?=\n##|\Z)", text, re.DOTALL)
        if m:
            val = m.group(1).strip()
            if target == "summary":
                summary = val
            elif target == "next_step":
                next_step = val
            elif target == "blockers_text":
                blockers_text = val
                blocker_count = sum(
                    1 for l in val.splitlines() if l.strip().startswith("-")
                )
            elif target == "tech_stack":
                tech_stack = val

# === Scripts ===
scripts = [
    ("AMG Price Monitor", "businesses/americana-getaways-llc/scripts/python/amg_hotel_price_monitor_v2.py"),
    ("AMG Test Suite",    "businesses/americana-getaways-llc/scripts/python/test_all_hotels.py"),
    ("AMG Post Gen",      "businesses/americana-getaways-llc/scripts/python/generate_posts.py"),
    ("AMG Route Opt",     "businesses/americana-getaways-llc/scripts/python/route_optimizer.py"),
    ("Frontier Monitor",  "businesses/side-projects/personal-projects/scripts/python/frontier_price_monitor.py"),
    ("Statusline Pet",    ".claude/statusline-pet.py"),
    ("Memory Loader",     "memory.sh"),
]

# === Buddy ===
buddy_status = "IDLE"
buddy_name = buddy_species = buddy_personality = ""
buddy_xp = buddy_level = 0
buddy_stage = "baby"
active_file = ROOT / "Pets/.active"
if active_file.exists():
    slug = active_file.read_text().strip()
    if slug:
        pet_file = ROOT / f"Pets/{slug}.md"
        if pet_file.exists():
            age = time.time() - pet_file.stat().st_mtime
            text = pet_file.read_text()
            m = re.search(r"^name:\s*(.+)$", text, re.MULTILINE)
            if m:
                buddy_name = m.group(1).strip()
            if age > 24 * 3600:
                buddy_status = "EXPIRED"
            else:
                buddy_status = "ACTIVE"
                for key in ("species", "personality", "xp", "level", "stage"):
                    m = re.search(rf"^{key}:\s*(.+)$", text, re.MULTILINE)
                    if m:
                        val = m.group(1).strip()
                        if key == "species":
                            buddy_species = val
                        elif key == "personality":
                            buddy_personality = val
                        elif key == "xp":
                            buddy_xp = int(val)
                        elif key == "level":
                            buddy_level = int(val)
                        elif key == "stage":
                            buddy_stage = val

# === Render ===
today = datetime.now().strftime("%Y-%m-%d")
B = "═" * IW
out = []

out.append("")
out.append(f"{C}╔{B}╗{R}")
title_txt = "HUMAN STANDARD — SYSTEM REPORT"
gap = IW - 2 - len(title_txt) - len(today) - 2
out.append(line(f"  {BW}{title_txt}{R}{' ' * gap}{Y}{today}{R}  "))
out.append(f"{C}╠{B}╣{R}")
out.append(line(""))

gov_m = int(gov_loaded / 5 * 20)
out.append(line(f"  {W}GOVERNANCE{R}    [{meter(gov_m)}] {V}{gov_loaded}/5 LOADED{R}"))
out.append(line(f"  {W}LESSONS{R}       [{meter(20)}] {V}{lesson_count} applied{R}"))
bc_color = BR if blocker_count > 0 else G
out.append(line(f"  {W}BLOCKERS{R}      {bc_color}{blocker_count} open{R}"))
out.append(line(""))

out.append(divider(f"{BY}SCRIPTS{R}", "SCRIPTS"))
out.append(line(""))
for label, path in scripts:
    exists = (ROOT / path).exists()
    badge = f"{BG}[FOUND]{R}  " if exists else f"{BR}[MISSING]{R}"
    fname = path.rsplit("/", 1)[-1]
    out.append(line(f"  {W}{label:<18}{R} {badge}  {V}{fname}{R}"))
out.append(line(""))

out.append(divider(f"{BB}TASKS{R}", "TASKS"))
out.append(line(""))
max_c = max(in_progress, completed, backlog, 1)
ip_m = int(in_progress / max_c * 20)
c_m = int(completed / max_c * 20)
bl_m = int(backlog / max_c * 20)
out.append(line(f"  {W}In Progress{R}   [{meter(ip_m)}]  {V}{in_progress}{R}"))
out.append(line(f"  {W}Completed{R}     [{meter(c_m)}]  {V}{completed}{R}"))
out.append(line(f"  {W}Backlog{R}       [{meter(bl_m)}]  {V}{backlog}{R}"))
out.append(line(""))

rainbow = f"{RR}B{RYel}U{RG}D{RC}D{RM}Y{R}"
out.append(divider(rainbow, "BUDDY"))
out.append(line(""))
if buddy_status == "ACTIVE":
    xp_m = int(buddy_xp / 455 * 20)
    if buddy_xp > 0 and xp_m == 0:
        xp_m = 1
    out.append(line(f"  {W}{buddy_name}{R}"))
    out.append(line(f"  {V}{buddy_species} · {buddy_personality}{R}"))
    out.append(line(f"  {W}XP{R} [{meter(xp_m)}] {V}{buddy_xp}/455  Lv {buddy_level} · {buddy_stage}{R}"))
    out.append(line(f"  {W}Status{R} [{BG}ACTIVE{R}]"))
elif buddy_status == "EXPIRED":
    out.append(line(f"  {Y}{buddy_name} has gone idle (>24h). Use /buddy to summon a new one.{R}"))
else:
    out.append(line(f"  {DG}No active buddy. Use /buddy to summon one.{R}"))
out.append(line(""))

out.append(divider(f"{BM}LAST SESSION{R}", "LAST SESSION"))
out.append(line(""))
for l in wrap_box(first_nonempty(summary) or "—"):
    out.append(l)
out.append(line(""))
for l in wrap_box(first_nonempty(next_step) or "—", "Next: ", f"{W}Next:{R} "):
    out.append(l)
for l in wrap_box(first_nonempty(tech_stack) or "—", "Stack: ", f"{W}Stack:{R} "):
    out.append(l)
out.append(line(""))

out.append(divider(f"{BR}BLOCKERS{R}", "BLOCKERS"))
out.append(line(""))
blocker_items = [
    MD_RE.sub("", ln.strip().lstrip("- ").strip())
    for ln in blockers_text.splitlines()
    if ln.strip().startswith("-")
] if blockers_text else []
if blocker_items:
    for i, item in enumerate(blocker_items, 1):
        for l in wrap_box(item, f"{i}. ", f"{BR}{i}.{R} "):
            out.append(l)
else:
    out.append(line(f"  {DG}No open blockers.{R}"))
out.append(line(""))
out.append(f"{C}╚{B}╝{R}")
out.append("")

print("\n".join(out))
