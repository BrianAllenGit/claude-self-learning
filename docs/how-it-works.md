# How It Works

## Session Start

When you open Claude Code in any project, the SessionStart hook runs immediately. It looks for `.claude/patterns/` in your project directory. If pattern files exist, it reads every `.md` file and injects them as `additionalContext` — the same mechanism Claude Code uses to inject system prompts. By the time you type your first message, Claude already knows what your project has learned.

## During the Session

Nothing special happens. Work normally. Run whatever skills you use.

## Session End — Two Paths

**If you ran `/reflect`:** The skill analyzed the live conversation, extracted patterns, wrote files, committed, and set a done flag at `.claude/.reflect-done`.

**If you didn't:** The Stop hook fires when Claude stops responding. It checks the done flag — if present, exits immediately. Otherwise it reads the conversation JSONL log from `~/.claude/projects/`, sends it to the Claude API using the extraction prompt in `shared/reflect-prompt.md`, parses the structured response, writes pattern files, commits them, and sets the done flag.

## Next Session

SessionStart deletes `.reflect-done` (so the Stop hook runs fresh) and injects whatever patterns were written last session. The cycle continues.

## The Naming Convention

Pattern files live at `.claude/patterns/<skill-name>/<type>.md`. The `<skill-name>` matches the folder name of the skill in `~/.claude/skills/`. This is the only connection between skills and their patterns — no skill modification needed.
