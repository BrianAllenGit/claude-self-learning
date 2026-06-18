---
name: self-learning
description: Explains how the self-learning plugin works and how to use it — pattern injection, auto-reflection, and the /reflect skill
---

# Self-Learning Skills System

This plugin makes every Claude skill self-improving. Here's how it works and how to use it.

## How It Works

When you install this plugin, two hooks are registered globally:

**SessionStart:** At the start of every session, the hook reads `.claude/patterns/` in your current project and injects the contents into Claude's context. Every skill automatically benefits from accumulated knowledge — no changes to the skills themselves needed.

**Stop:** When Claude stops, if reflection hasn't run yet, the hook calls the Claude API to analyze the conversation and extract learnings. It writes them to `.claude/patterns/` in your project and commits them.

## The /reflect Skill

Run `/reflect` at any point during a session to trigger reflection while the conversation is still in context. This is more accurate than the automatic Stop hook because Claude reads the live session rather than a log file.

If you run `/reflect`, the Stop hook will detect the done flag and skip its automatic run.

## Pattern Files

Patterns live at `.claude/patterns/<skill-name>/` in each repo and are committed to git. They grow over time — each reflect run merges new learnings into the existing files.

```
.claude/patterns/
  dev-workflow/
    backend.md
    frontend.md
  code-review/
    general.md
```

Teammates benefit automatically when they pull — as long as they have this plugin installed.

## What Gets Captured

- **Anti-Patterns:** Things the user corrected or redirected
- **Confirmed Patterns:** Approaches the user validated  
- **Stack:** Libraries, frameworks, key tech in this repo
- **Conventions:** Naming patterns, file structure, style decisions

## Making a Skill Self-Learning

Any skill benefits automatically from this plugin with no changes needed. The SessionStart hook injects patterns before any skill runs.

To write patterns back for a specific skill, the skill name must match the folder name in `~/.claude/skills/`. The reflect skill uses that name to determine where to write patterns.
