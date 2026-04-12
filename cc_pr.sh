#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <claude_path>] [--timeout <seconds>]"
  echo "  --cc <path>       Path to claude CLI (default: claude)"
  echo "  --timeout <sec>   Timeout in seconds (default: 600)"
  echo ""
  echo "Run in a git repo. Generates commit (type emoji: desc), pushes, and creates PR."
  exit 1
}

CC_BIN="claude"
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --cc) CC_BIN="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting PR creation..."
log "Claude CLI: ${CC_BIN}, Timeout: ${TIMEOUT}s"

if ! command -v "$CC_BIN" &>/dev/null; then
  log "ERROR: claude CLI not found at '${CC_BIN}'"
  exit 1
fi

log "Collecting changes..."
CHANGES=""

# Staged changes
STAGED=$(git diff --cached 2>/dev/null)
if [ -n "$STAGED" ]; then
  log "Found staged changes"
  CHANGES+="=== Staged Changes ===
${STAGED}

"
fi

# Unstaged tracked file changes
UNSTAGED=$(git diff 2>/dev/null)
if [ -n "$UNSTAGED" ]; then
  log "Found unstaged changes"
  CHANGES+="=== Unstaged Changes ===
${UNSTAGED}

"
fi

# Untracked new files - show full content
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)
if [ -n "$UNTRACKED" ]; then
  FILE_COUNT=$(echo "$UNTRACKED" | wc -l | tr -d ' ')
  log "Found ${FILE_COUNT} untracked file(s)"
  UNTRACKED_CONTENT="=== Untracked Files ===
"
  while IFS= read -r f; do
    log "  + ${f}"
    UNTRACKED_CONTENT+="--- /dev/null
+++ b/${f}
$(sed 's/^/+/' "$f" 2>/dev/null)

"
  done <<< "$UNTRACKED"
  CHANGES+="$UNTRACKED_CONTENT"
fi

if [ -z "$CHANGES" ]; then
  log "ERROR: No changes found (no staged, unstaged, or untracked files)"
  exit 1
fi

PROMPT="Based on the following git diff, do these steps:

1. Generate a commit message following this format strictly:
   type emoji: description
   
   Where type is one of: feat, fix, docs, style, refactor, perf, test, chore, ci, build
   And emoji matches the type:
   - feat ✨: new feature
   - fix 🐛: bug fix
   - docs 📝: documentation
   - style 💄: formatting/style
   - refactor ♻️: refactoring
   - perf ⚡: performance
   - test ✅: tests
   - chore 🔧: chores
   - ci 👷: CI/CD
   - build 📦: build system

2. Stage all changes with git add
3. Commit with the generated message
4. Push to remote
5. Create a PR using gh cli (if available) with a clear title and description

\`\`\`diff
${CHANGES}
\`\`\`"

log "Sending to claude for PR creation..."
START_TIME=$(date +%s)

timeout "${TIMEOUT}" "$CC_BIN" -p --dangerously-skip-permissions "$PROMPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 124 ]; then
  log "ERROR: PR creation timed out after ${TIMEOUT}s"
  exit 1
fi

log "PR creation completed in ${ELAPSED}s (exit code: ${EXIT_CODE})"
