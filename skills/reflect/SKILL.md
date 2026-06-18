# /reflect — Self-Learning Pattern Extractor

Analyze the current conversation and extract learnings into this repo's pattern files.

## Process

**Step 1: Identify active skills and work type**

Scan the conversation for:
- Skill tool invocations → skill name (e.g., `dev-workflow`, `code-review`). If none, use `general`.
- File paths in Edit/Write/Read tool calls → classify as `backend`, `frontend`, or `general` based on directory names.

**Step 2: Extract patterns using these four categories**

Apply the same logic from `shared/reflect-prompt.md` in this plugin:
- Corrections/pushbacks from the user → Anti-Patterns
- Validated/confirmed approaches → Confirmed Patterns  
- Project context that emerged → Stack and Conventions
- Only capture what's specific and actionable. Skip generic advice.

**Step 3: Read existing pattern files before writing**

Check if `.claude/patterns/<skill-name>/<type>.md` already exists. If it does, read it first and merge new learnings into the existing sections. Never overwrite content that isn't contradicted.

**Step 4: Write updated pattern files**

Write to `.claude/patterns/<skill-name>/<type>.md`. Use this structure:

```markdown
# <Type> Patterns — <repo-name>

## Stack
- ...

## Conventions
- ...

## Confirmed Patterns
- ...

## Anti-Patterns
- ...

## Last updated: <today's date>
```

Only include sections with actual content.

**Step 5: Commit the pattern files**

```bash
git add .claude/patterns/
git commit -m "chore: update learned patterns"
```

**Step 6: Write the done flag**

Write the current timestamp to `.claude/.reflect-done`:

```
<timestamp>
```

**Step 7: Report to the user**

Tell the user what was captured: which skill, which type (backend/frontend/general), and a brief summary of what was learned. If nothing was worth capturing, say so.

## When nothing is worth capturing

If the session was short Q&A with no real work, no corrections, and no validated patterns — say so and skip steps 3–6. Don't write empty or trivially small pattern files.
