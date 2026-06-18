# Self-Learning Claude Skills Plugin — Design Spec

**Date:** 2026-06-18  
**Status:** Approved  
**Repo:** `claude-self-learning` (public)

---

## Overview

A Claude Code plugin that makes any skill self-improving. When installed, it registers hooks that automatically inject learned patterns into every session and run reflection analysis at session end. Skills accumulate per-repo knowledge over time without any user intervention.

---

## Architecture

Three layers:

**Global layer** (`~/.claude/skills/`) — skill definitions that never change per-project. The `reflect` skill and `self-learning` documentation skill live here. Pulled from the public GitHub repo.

**Per-repo layer** (`.claude/patterns/<skill-name>/`) — markdown files that live inside each project repo and are committed to git. These grow over time as reflect writes to them. They travel with the repo so teammates benefit too (if they have the plugin installed).

**Hook layer** — two globally registered hooks that handle automatic injection (SessionStart) and automatic reflection (Stop).

---

## How Any Skill Becomes Self-Learning

Skill authors add one line near the top of their `SKILL.md`:

```markdown
## Before starting
Read `.claude/patterns/<skill-name>/` in the current repo if it exists. Treat all `.md` files there as additional instructions that refine the defaults below.
```

The folder name convention links the skill to its per-repo pattern folder. No other modification needed.

The SessionStart hook additionally reads and injects the full contents of all pattern files into every session automatically, so patterns are in context before any skill is even invoked.

---

## Pattern File Structure

Pattern files are human-readable markdown stored at `.claude/patterns/<skill-name>/`:

```
.claude/patterns/
  dev-workflow/
    backend.md       ← patterns for backend work in this repo
    frontend.md      ← patterns for frontend work in this repo
    general.md       ← cross-cutting project conventions
  code-review/
    patterns.md      ← what this repo cares about in reviews
```

File classification (backend vs frontend vs general) is determined by which directories were touched during the session (file paths in tool calls).

**Example pattern file:**
```markdown
# Backend Patterns — <repo-name>

## Stack
- Node.js + Express, MongoDB via Mongoose

## Conventions
- Routes in backend/routes/, grouped by feature
- Services in backend/services/<feature>/
- Always async/await, never callbacks

## Confirmed Patterns
- Business logic belongs in service layer, not route handlers

## Anti-Patterns
- Don't mock MongoDB in tests

## Last updated: YYYY-MM-DD
```

Reflect **merges, never overwrites** — existing entries persist unless explicitly contradicted.

---

## The Reflect Skill (`/reflect`)

A standalone skill at `~/.claude/skills/reflect/SKILL.md`. Can be invoked manually at any time during a session. Shared by all self-learning skills as the write engine.

**Extraction logic — answers four questions:**

1. **Which skill was active and what work type?** Scans for Skill tool invocations to identify skill name. Scans file paths in Edit/Write/Read calls to classify as backend, frontend, or general.

2. **What did the user correct?** Phrases like "no, not that", pushbacks, redirections → written as **Anti-Patterns**.

3. **What did the user validate?** Explicit confirmations, accepted approaches without pushback → written as **Confirmed Patterns**. Captures what works, not just what doesn't.

4. **What project-specific context emerged?** Libraries, naming conventions, file structure decisions, preferences a future session would waste time re-discovering → written under **Stack** and **Conventions**.

---

## Reflection Trigger (Option D)

Two paths, same extraction logic, same output:

**In-session (`/reflect`):** Claude reads the live conversation context and applies the extraction logic directly. Writes pattern files, commits, sets the done flag.

**Out-of-session (Stop hook):** Fires when Claude stops. Checks the done flag — if already reflected, exits. Otherwise reads the conversation JSONL log from `~/.claude/projects/<encoded-path>/`, makes a Claude API call using the reflect extraction prompt as the system prompt, parses the response, merges pattern files, commits, sets done flag.

**Done flag:** `.claude/.reflect-done` — written after any reflect run, deleted by SessionStart hook at the start of each new session. Prevents double-reflection when both paths would otherwise trigger.

**Session worthiness check (Stop hook only):** Skip reflection if no files were modified during the session (short Q&A with no meaningful work). Checked via `git status`.

---

## Hook Layer

### SessionStart Hook

```
1. Delete .claude/.reflect-done (fresh session)
2. Check if .claude/patterns/ exists in current project
3. If yes: read all .md files across all skill subfolders
4. Inject as additionalContext:
   <learned-patterns>
   [contents of all pattern files]
   </learned-patterns>
```

### Stop Hook

```
1. Check .claude/.reflect-done — exit if present
2. Check git status — exit if no file changes (unproductive session)
3. Find latest conversation JSONL in ~/.claude/projects/<encoded-path>/
4. Scan conversation log for Skill tool invocations to determine which skill(s) were active
5. POST to Claude API: system=shared/reflect-prompt.md, user=conversation log
6. Parse response → merge into .claude/patterns/<skill-name>/<type>.md
7. git add .claude/patterns/ && git commit -m "chore: update learned patterns"
8. Write .claude/.reflect-done
```

API key sourced from `$ANTHROPIC_API_KEY` — present in all Claude Code environments.

---

## Plugin Repository Structure

```
claude-self-learning/
  README.md
  .claude-plugin/
    plugin.json                        ← name, version, author
  hooks/
    hooks.json                         ← registers SessionStart + Stop
    session-start.sh                   ← pattern injection
    stop.sh                            ← auto-reflection
  shared/
    reflect-prompt.md                  ← extraction prompt (used by both stop.sh and /reflect skill)
  skills/
    reflect/
      SKILL.md                         ← the /reflect skill
    self-learning/
      SKILL.md                         ← documents the system, explains convention
  docs/
    specs/
      2026-06-18-self-learning-plugin-design.md
    how-it-works.md
    writing-self-learning-skills.md    ← one-liner convention for skill authors
```

---

## Portability

Install once per machine → all repos and all skills benefit:
- SessionStart hook injects patterns from any repo that has `.claude/patterns/`
- Stop hook reflects on any session regardless of which skill was used
- Per-repo pattern files travel via git — teammates on the same repo get the accumulated knowledge as soon as they pull (plugin must be installed to use it)

---

## Out of Scope

- Pattern file size limits / pruning (future concern once files actually grow large)
- Multi-user conflict resolution on pattern files (treat like any other committed file — normal git merge)
- Pattern sharing across repos (each repo owns its patterns independently)
