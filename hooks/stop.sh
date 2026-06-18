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

# Detect Python (python3, python, or py on Windows)
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || command -v py 2>/dev/null || true)
if [ -z "$PYTHON" ]; then
  exit 0
fi

# Find the most recent conversation JSONL using Python for reliable cross-platform mtime comparison
PROJECTS_DIR="${HOME}/.claude/projects"
if [ ! -d "$PROJECTS_DIR" ]; then
  exit 0
fi

conversation_file=$(PROJECTS_DIR_VAL="$PROJECTS_DIR" "$PYTHON" - <<'PYEOF'
import os, glob

projects_dir = os.environ["PROJECTS_DIR_VAL"]
jsonl_files = glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True)
if jsonl_files:
    print(max(jsonl_files, key=os.path.getmtime))
PYEOF
)

if [ -z "$conversation_file" ] || [ ! -f "$conversation_file" ]; then
  exit 0
fi

# Read reflect prompt and conversation (cap at 50k chars to manage tokens)
REFLECT_PROMPT=$(cat "${PLUGIN_ROOT}/shared/reflect-prompt.md")
conversation=$(tail -c 50000 "$conversation_file")

# Build and send API request — pass data via env vars to avoid heredoc injection
response=$(REFLECT_PROMPT_VAL="$REFLECT_PROMPT" CONVERSATION_VAL="$conversation" "$PYTHON" - <<'PYEOF'
import json, urllib.request, os

prompt = os.environ["REFLECT_PROMPT_VAL"]
conversation = os.environ["CONVERSATION_VAL"]

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
# Normalize line endings before matching to handle \r\n from HTTP responses
RESPONSE_VAL="$response" PROJECT_DIR_VAL="$PROJECT_DIR" "$PYTHON" - <<'PYEOF'
import re, os

response = os.environ["RESPONSE_VAL"].replace('\r\n', '\n')
project_dir = os.environ["PROJECT_DIR_VAL"]

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
