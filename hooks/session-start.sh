#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
