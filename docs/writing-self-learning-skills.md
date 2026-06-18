# Writing Self-Learning Skills

Any skill in `~/.claude/skills/` is automatically self-learning when this plugin is installed. No changes to the skill needed.

## How the Naming Works

If your skill lives at `~/.claude/skills/my-skill/SKILL.md`, the reflect system writes patterns to `.claude/patterns/my-skill/` in each repo.

That's the entire convention. Nothing else required.

## What Gets Injected

At session start, the hook reads every `.md` file under `.claude/patterns/my-skill/` and injects them verbatim into context before your skill runs. Claude sees them as part of its instructions.

## Pattern File Types

The reflect system writes up to three files per skill per repo:

- `backend.md` — patterns from sessions where backend files were touched
- `frontend.md` — patterns from sessions where frontend files were touched  
- `general.md` — patterns from sessions where neither, or both, were touched

Your skill doesn't need to know which file it's reading — the hook injects all of them.

## Testing Your Skill With Patterns

Create `.claude/patterns/my-skill/general.md` in a test repo with some content. Start a Claude Code session. Your skill should incorporate that content in its behavior.
