---
name: done
description: Run the session shutdown sequence. Use this skill when the user types /done or says they're wrapping up, ending the session, or done for the day. Updates primer.md and memory files so the next session starts with full context. Always invoke this before the user closes the session.
---

# Session Shutdown Sequence

The user is ending this session. Your job is to capture everything that happened so the next session starts with zero context loss.

## Step 1 — Update primer.md for each active project

For every project touched this session, rewrite its `primer.md` completely. Keep it under 100 lines. Include:

- **Active Project** — what it is
- **What Was Just Completed** — specific, concrete (not vague summaries)
- **Exact Next Step** — one clear action, not a list
- **Open Blockers** — anything unresolved or unclear

If work happened across multiple projects (e.g., both `Businesses/AMG/` and `Businesses/side-projects/`), update each project's `primer.md` individually. Also update the root `.claude/primer.md` with a cross-project summary.

The test for a good primer: could a fresh Claude session read it and immediately know exactly what to do next, without asking questions?

## Step 2 — Update memory files

Check your Claude Code project memory directory (`~/.claude/projects/<project-slug>/memory/` — slug is the project path with `/` replaced by `-`) for anything that should be updated based on this session:

- Did the user correct your approach? → update or add a `feedback_*.md`
- Did you learn something about the user's preferences or role? → update `user_*.md`
- Did a project's status change significantly? → update `project_*.md`
- Did a new external resource or reference come up? → add `reference_*.md`

Only write what's genuinely useful in future sessions. Don't duplicate what's already in primer.md or derivable from the code.

Update `MEMORY.md` index if you added or changed any files.

## Step 3 — Confirm

Reply with a short confirmation:
- Which primers were updated and what the next step is for each
- Which memory files were changed (if any)
- Reminder to close the session
