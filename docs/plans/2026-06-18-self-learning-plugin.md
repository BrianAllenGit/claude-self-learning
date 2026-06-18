# Self-Learning Claude Skills Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that makes every skill self-improving by injecting learned per-repo patterns at session start and automatically reflecting on sessions at close.

**Architecture:** A plugin with two bash hooks (SessionStart injects patterns from `.claude/patterns/`, Stop runs reflection via the Claude API) plus a `/reflect` skill for in-session use. A shared extraction prompt drives both reflection paths. Per-repo pattern files live in `.claude/patterns/<skill-name>/` and are committed to each project's git history.

**Tech Stack:** Bash, Claude API (Anthropic), Markdown, Claude Code plugin system

---

## File Map

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin metadata and identity |
| `hooks/hooks.json` | Registers SessionStart and Stop hooks with Claude Code |
| `hooks/session-start.sh` | Reads `.claude/patterns/` and injects contents as session context |
| `hooks/stop.sh` | Checks flag, finds conversation JSONL, calls Claude API, writes patterns, commits |
| `shared/reflect-prompt.md` | Extraction prompt template — used by both stop.sh and the /reflect skill |
| `skills/reflect/SKILL.md` | The `/reflect` skill — in-session reflection path |
| `skills/self-learning/SKILL.md` | Documents the plugin system for users and skill authors |
| `docs/how-it-works.md` | End-user explanation |
| `docs/writing-self-learning-skills.md` | Guide for skill authors |
| `README.md` | Installation, quick start, overview |
| `tests/test-session-start.sh` | Tests for session-start.sh |
| `tests/fixtures/patterns/dev-workflow/backend.md` | Test fixture: sample pattern file |

---

## Task 1: Plugin Scaffolding

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `hooks/hooks.json`

- [ ] **Step 1: Create `.claude-plugin/plugin.json`**

```json
{
  "name": "self-learning",
  "description": "Makes any Claude skill self-improving through automatic per-repo pattern learning",
  "version": "1.0.0",
  "author": {
    "name": "BrianAllenGit"
  },
  "homepage": "https://github.com/BrianAllenGit/claude-self-learning",
  "repository": "https://github.com/BrianAllenGit/claude-self-learning",
  "license": "MIT"
}
```

- [ ] **Step 2: Create `hooks/hooks.json`**

This registers both hooks with Claude Code. Stop runs async so it doesn't block the session close.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"",
            "async": false
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/stop.sh\"",
            "async": true
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/ hooks/hooks.json
git commit -m "feat: add plugin manifest and hook registration"
```

---

## Task 2: Shared Reflect Extraction Prompt

**Files:**
- Create: `shared/reflect-prompt.md`

This is the brain of the system. Both `stop.sh` (out-of-session) and `/reflect` (in-session) use this same logic. It instructs Claude what to extract and how to format the output so `stop.sh` can parse it.

- [ ] **Step 1: Create `shared/reflect-prompt.md`**

```markdown
You are a pattern extractor for a self-improving Claude skills system.

You will be given a Claude Code conversation transcript. Your job is to extract learnings and write them as pattern files that will improve future sessions on this repository.

## What to extract

**1. Which skill(s) were active?**
Look for lines containing `Skill tool` invocations or skill names like `dev-workflow`, `code-review`, `brainstorming` etc. These determine which pattern folder to write to. If no skill was explicitly invoked, use `general`.

**2. What type of work happened?**
Look at file paths in Edit, Write, and Read tool calls:
- Files under `backend/`, `server/`, `api/`, `routes/`, `services/`, `models/` → backend
- Files under `frontend/`, `src/components/`, `pages/`, `public/` → frontend
- Files touched in both areas → write separate backend and frontend entries
- Neither → general

**3. What did the user correct or redirect?** (Anti-Patterns)
Look for: user pushback, "no not that", "don't do X", "stop doing Y", moments where Claude changed course after user feedback, approaches that were tried and then reversed. These are high-signal learnings.

**4. What did the user validate?** (Confirmed Patterns)
Look for: "yes exactly", "perfect", "that's right", approaches accepted without pushback, non-obvious choices the user let stand. Capturing these prevents the system from only learning what NOT to do.

**5. What project context emerged?** (Stack + Conventions)
Libraries used, naming patterns, file structure decisions, testing philosophy, anything a fresh Claude session would waste time re-discovering about this specific repo.

## Output format

Output ONLY pattern files in this exact format. No other text.

For each skill+type combination that has learnings:

=== FILE: .claude/patterns/<skill-name>/<type>.md ===
# <Type> Patterns — <repo-name if identifiable, otherwise "this repo">

## Stack
- [key technologies, frameworks, libraries used]

## Conventions
- [naming patterns, file structure, style decisions]

## Confirmed Patterns
- [things that worked, approaches the user validated]

## Anti-Patterns
- [things to avoid, corrections the user made]

## Last updated: <today's date YYYY-MM-DD>
=== END ===

## Rules

- Only include sections that have actual content. Omit empty sections entirely.
- If a section already exists in a pattern file you're updating, merge don't duplicate.
- Be specific. "Use async/await" is useful. "Write good code" is not.
- If there's nothing worth capturing (short Q&A, no real work done), output nothing at all.
- The `<type>` in the filename must be one of: `backend`, `frontend`, `general`.
```

- [ ] **Step 2: Commit**

```bash
git add shared/reflect-prompt.md
git commit -m "feat: add shared reflection extraction prompt"
```

---

## Task 3: SessionStart Hook

**Files:**
- Create: `hooks/session-start.sh`
- Create: `tests/test-session-start.sh`
- Create: `tests/fixtures/patterns/dev-workflow/backend.md`

- [ ] **Step 1: Create test fixture**

Create `tests/fixtures/patterns/dev-workflow/backend.md`:

```markdown
# Backend Patterns — test-repo

## Stack
- Node.js + Express

## Conventions
- Routes in backend/routes/

## Confirmed Patterns
- Business logic in service layer

## Anti-Patterns
- No callbacks, use async/await
```

- [ ] **Step 2: Write the test first**

Create `tests/test-session-start.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/session-start.sh"

pass=0
fail=0

run_test() {
  local name="$1"
  local result="$2"
  local expected="$3"
  if echo "$result" | grep -q "$expected"; then
    echo "PASS: $name"
    ((pass++))
  else
    echo "FAIL: $name"
    echo "  Expected to find: $expected"
    echo "  Got: $result"
    ((fail++))
  fi
}

# Test 1: With patterns present, injects additionalContext
tmp_project=$(mktemp -d)
mkdir -p "${tmp_project}/.claude/patterns/dev-workflow"
cp "${TESTS_DIR}/fixtures/patterns/dev-workflow/backend.md" \
   "${tmp_project}/.claude/patterns/dev-workflow/backend.md"

result=$(CLAUDE_PROJECT_DIR="$tmp_project" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK")
run_test "injects learned-patterns tag" "$result" "learned-patterns"
run_test "injects pattern content" "$result" "Node.js"
run_test "outputs hookSpecificOutput" "$result" "hookSpecificOutput"

# Test 2: No patterns directory — exits cleanly with no output
tmp_empty=$(mktemp -d)
result=$(CLAUDE_PROJECT_DIR="$tmp_empty" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK")
run_test "empty project outputs nothing" "$result" ""

# Test 3: Deletes .reflect-done flag on start
tmp_flag=$(mktemp -d)
mkdir -p "${tmp_flag}/.claude"
touch "${tmp_flag}/.claude/.reflect-done"
CLAUDE_PROJECT_DIR="$tmp_flag" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" > /dev/null
if [ ! -f "${tmp_flag}/.claude/.reflect-done" ]; then
  echo "PASS: deletes .reflect-done flag"
  ((pass++))
else
  echo "FAIL: should have deleted .reflect-done flag"
  ((fail++))
fi

rm -rf "$tmp_project" "$tmp_empty" "$tmp_flag"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 3: Run test — verify it fails**

```bash
bash tests/test-session-start.sh
```

Expected: FAIL (hook script doesn't exist yet)

- [ ] **Step 4: Create `hooks/session-start.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CLAUDE_DIR="${PROJECT_DIR}/.claude"

# Start each session clean so Stop hook can reflect
rm -f "${CLAUDE_DIR}/.reflect-done"

PATTERNS_DIR="${CLAUDE_DIR}/patterns"
if [ ! -d "$PATTERNS_DIR" ]; then
  exit 0
fi

# Collect all pattern file contents
patterns_content=""
while IFS= read -r -d '' file; do
  skill_name=$(basename "$(dirname "$file")")
  type_name=$(basename "$file" .md)
  file_content=$(cat "$file")
  patterns_content="${patterns_content}\n\n#### ${skill_name}/${type_name}\n\n${file_content}"
done < <(find "$PATTERNS_DIR" -name "*.md" -print0 2>/dev/null | sort -z)

if [ -z "$patterns_content" ]; then
  exit 0
fi

escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

context="<learned-patterns>\nThe following patterns have been learned for this repository. Apply them throughout this session.\n${patterns_content}\n</learned-patterns>"
context_escaped=$(escape_for_json "$context")

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$context_escaped"
```

- [ ] **Step 5: Make executable**

```bash
chmod +x hooks/session-start.sh
```

- [ ] **Step 6: Run test — verify it passes**

```bash
bash tests/test-session-start.sh
```

Expected:
```
PASS: injects learned-patterns tag
PASS: injects pattern content
PASS: outputs hookSpecificOutput
PASS: empty project outputs nothing
PASS: deletes .reflect-done flag
Results: 5 passed, 0 failed
```

- [ ] **Step 7: Commit**

```bash
git add hooks/session-start.sh tests/
git commit -m "feat: add SessionStart hook for pattern injection"
```

---

## Task 4: The /reflect Skill

**Files:**
- Create: `skills/reflect/SKILL.md`

This is the in-session reflection path. Claude reads this skill, analyzes the live conversation in context, and writes pattern files directly using the Write tool.

- [ ] **Step 1: Create `skills/reflect/SKILL.md`**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add skills/reflect/
git commit -m "feat: add /reflect in-session skill"
```

---

## Task 5: Stop Hook (Auto-Reflection)

**Files:**
- Create: `hooks/stop.sh`

This is the out-of-session path. It fires when Claude stops, checks the flag, finds the conversation log, calls the Claude API, parses the response, and writes pattern files.

- [ ] **Step 1: Verify `python3` is available on your system**

```bash
python3 --version
```

Expected: Python 3.x.x — required for JSON parsing in the hook.

- [ ] **Step 2: Find where Claude Code saves conversation logs on your machine**

```bash
ls ~/.claude/projects/
```

Note the directory structure. Each project gets a folder. JSONL files inside are the conversation logs. Confirm the path pattern before implementing the hook.

- [ ] **Step 3: Create `hooks/stop.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CLAUDE_DIR="${PROJECT_DIR}/.claude"

# Skip if reflect already ran this session
if [ -f "${CLAUDE_DIR}/.reflect-done" ]; then
  exit 0
fi

# Skip if no files were changed (unproductive session)
if git -C "$PROJECT_DIR" diff --quiet HEAD 2>/dev/null; then
  exit 0
fi

# Skip if no API key
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  exit 0
fi

# Find the most recent conversation JSONL for this project
# Claude Code stores conversations at ~/.claude/projects/<encoded-path>/
PROJECTS_DIR="${HOME}/.claude/projects"
if [ ! -d "$PROJECTS_DIR" ]; then
  exit 0
fi

# Find the most recently modified JSONL across all project folders
conversation_file=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f 2>/dev/null \
  | xargs ls -t 2>/dev/null \
  | head -1)

if [ -z "$conversation_file" ] || [ ! -f "$conversation_file" ]; then
  exit 0
fi

# Read reflect prompt and conversation (cap at 50k chars to manage tokens)
REFLECT_PROMPT=$(cat "${PLUGIN_ROOT}/shared/reflect-prompt.md")
conversation=$(tail -c 50000 "$conversation_file")

# Build and send API request
response=$(python3 - <<PYEOF
import json, urllib.request, os

prompt = """${REFLECT_PROMPT}"""
conversation = """${conversation}"""

payload = json.dumps({
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 2048,
    "system": prompt,
    "messages": [{"role": "user", "content": conversation}]
}).encode()

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=payload,
    headers={
        "Content-Type": "application/json",
        "x-api-key": os.environ["ANTHROPIC_API_KEY"],
        "anthropic-version": "2023-06-01"
    }
)

with urllib.request.urlopen(req) as r:
    data = json.loads(r.read())
    print(data["content"][0]["text"])
PYEOF
)

if [ -z "$response" ]; then
  exit 0
fi

# Parse response and write pattern files
# Expected format: === FILE: .claude/patterns/skill/type.md ===\n[content]\n=== END ===
python3 - <<PYEOF
import re, os

response = """${response}"""
project_dir = "${PROJECT_DIR}"

pattern = r'=== FILE: (.+?) ===\n(.*?)\n=== END ==='
matches = re.findall(pattern, response, re.DOTALL)

for filepath, content in matches:
    full_path = os.path.join(project_dir, filepath.strip())
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w') as f:
        f.write(content.strip() + '\n')
    print(f"wrote {filepath.strip()}")
PYEOF

# Commit if pattern files were written
patterns_dir="${CLAUDE_DIR}/patterns"
if [ -d "$patterns_dir" ] && git -C "$PROJECT_DIR" status --porcelain "$patterns_dir" 2>/dev/null | grep -q .; then
  git -C "$PROJECT_DIR" add "$patterns_dir"
  git -C "$PROJECT_DIR" commit -m "chore: update learned patterns [skip ci]"
fi

# Set done flag
mkdir -p "${CLAUDE_DIR}"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "${CLAUDE_DIR}/.reflect-done"
```

- [ ] **Step 4: Make executable**

```bash
chmod +x hooks/stop.sh
```

- [ ] **Step 5: Smoke test against a real JSONL file**

Find a recent Claude Code conversation log:

```bash
ls -lt ~/.claude/projects/ | head -5
```

Run the stop hook manually against your current project to verify it runs without errors (it may output nothing if the session didn't produce file changes — that's correct):

```bash
CLAUDE_PROJECT_DIR=$(pwd) CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/stop.sh
echo "exit: $?"
```

Expected: exits 0 with no errors. If patterns were worth writing, you'll see `wrote .claude/patterns/...` output.

- [ ] **Step 6: Commit**

```bash
git add hooks/stop.sh
git commit -m "feat: add Stop hook for auto-reflection"
```

---

## Task 6: Self-Learning Documentation Skill

**Files:**
- Create: `skills/self-learning/SKILL.md`

- [ ] **Step 1: Create `skills/self-learning/SKILL.md`**

```markdown
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
    patterns.md
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
```

- [ ] **Step 2: Commit**

```bash
git add skills/self-learning/
git commit -m "feat: add self-learning documentation skill"
```

---

## Task 7: Documentation and README

**Files:**
- Modify: `README.md`
- Create: `docs/how-it-works.md`
- Create: `docs/writing-self-learning-skills.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# claude-self-learning

A Claude Code plugin that makes every skill self-improving.

Install it once. Every repo you work in builds a `.claude/patterns/` folder that grows smarter every session.

## How It Works

- **SessionStart hook** injects learned patterns into every session automatically
- **Stop hook** analyzes the session and updates patterns when you close
- **`/reflect`** runs the same analysis in-session, with full context, anytime you want

Patterns live in `.claude/patterns/` inside each repo, committed to git. Teammates get them when they pull.

## Install

```bash
claude plugins install BrianAllenGit/claude-self-learning
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
        patterns.md
```

## Making Your Own Self-Learning Skill

See [docs/writing-self-learning-skills.md](docs/writing-self-learning-skills.md).

## License

MIT
```

- [ ] **Step 2: Write `docs/how-it-works.md`**

```markdown
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
```

- [ ] **Step 3: Write `docs/writing-self-learning-skills.md`**

```markdown
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
```

- [ ] **Step 4: Commit**

```bash
git add README.md docs/how-it-works.md docs/writing-self-learning-skills.md
git commit -m "docs: add README, how-it-works, and skill author guide"
```

- [ ] **Step 5: Push everything**

```bash
git push
```

---

## Self-Review

**Spec coverage check:**
- ✅ SessionStart hook — Task 3
- ✅ Stop hook — Task 5
- ✅ /reflect skill — Task 4
- ✅ Shared reflect prompt — Task 2
- ✅ Plugin manifest + hook registration — Task 1
- ✅ Done flag (create/delete) — Task 3 (delete in session-start.sh), Task 4 and 5 (create in reflect/stop)
- ✅ Pattern file structure — Task 2 (prompt defines format), Task 4 (skill writes it), Task 5 (stop hook writes it)
- ✅ Merges, never overwrites — covered in reflect-prompt.md and /reflect skill instructions
- ✅ Session worthiness check — Task 5 (git diff check in stop.sh)
- ✅ Public repo structure — Tasks 1–7 produce exactly the file map in the spec
- ✅ Documentation — Task 7

**Placeholder scan:** No TBDs or TODOs found. All code blocks contain actual implementation.

**Type consistency:** `reflect-prompt.md` output format (`=== FILE: ... === ... === END ===`) is defined in Task 2 and parsed in Task 5 — consistent. The done flag path (`.claude/.reflect-done`) is used consistently across Tasks 3, 4, and 5.
