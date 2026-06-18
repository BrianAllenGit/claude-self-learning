#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/session-start.sh"

pass=0
fail=0

tmp_project=""
tmp_empty=""
tmp_flag=""
cleanup() { rm -rf "${tmp_project:-}" "${tmp_empty:-}" "${tmp_flag:-}"; }
trap cleanup EXIT

run_test() {
  local name="$1"
  local result="$2"
  local expected="$3"
  if echo "$result" | grep -q "$expected"; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    echo "  Expected to find: $expected"
    echo "  Got: $result"
    fail=$((fail + 1))
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
if [ -z "$result" ]; then
  echo "PASS: empty project outputs nothing"
  pass=$((pass + 1))
else
  echo "FAIL: empty project outputs nothing"
  echo "  Expected empty output, got: $result"
  fail=$((fail + 1))
fi

# Test 3: Deletes .reflect-done flag on start
tmp_flag=$(mktemp -d)
mkdir -p "${tmp_flag}/.claude"
touch "${tmp_flag}/.claude/.reflect-done"
CLAUDE_PROJECT_DIR="$tmp_flag" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" > /dev/null
if [ ! -f "${tmp_flag}/.claude/.reflect-done" ]; then
  echo "PASS: deletes .reflect-done flag"
  pass=$((pass + 1))
else
  echo "FAIL: should have deleted .reflect-done flag"
  fail=$((fail + 1))
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
