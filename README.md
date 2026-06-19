# claude-self-learning

A Claude Code plugin that makes every skill self-improving.

Install it once. Every repo you work in builds a `.claude/patterns/` folder that grows smarter every session.

## How It Works

- **SessionStart hook** injects learned patterns into every session automatically
- **Stop hook** analyzes the session and updates patterns when you close
- **`/reflect`** runs the same analysis in-session, with full context, anytime you want

Patterns live in `.claude/patterns/` inside each repo, committed to git. Teammates get them when they pull.

## Install

In Claude Code, run these two slash commands:

```
/plugin marketplace add BrianAllenGit/claude-self-learning
/plugin install self-learning@brian-allen
```

Requires `ANTHROPIC_API_KEY` in your environment for the automatic Stop hook.

## Usage

Just work normally. Patterns accumulate automatically.

Run `/reflect` at the end of a productive session for higher-quality pattern extraction while the conversation is still in context.

## Pattern Files

```
your-repo/
  .claude/
    patterns/
      dev-workflow/
        backend.md    ← grows smarter every session
        frontend.md
      code-review/
        general.md
```

## Making Your Own Self-Learning Skill

See [docs/writing-self-learning-skills.md](docs/writing-self-learning-skills.md).

## License

MIT
