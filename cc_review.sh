#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <claude_path>] [--timeout <seconds>]"
  echo "  --cc <path>       Path to claude CLI (default: claude)"
  echo "  --timeout <sec>   Timeout in seconds (default: 300)"
  echo ""
  echo "Run in a git repo. Reviews uncommitted/untracked changes."
  exit 1
}

CC_BIN="claude"
TIMEOUT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --cc) CC_BIN="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting code review..."
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

PROMPT="You are a senior code reviewer. Review the following git diff carefully.

Focus on:
1. Bugs and logic errors
2. Security issues
3. Performance problems
4. Code style and readability
5. Missing edge cases

Provide a structured review with severity levels (critical/warning/info).

\`\`\`diff
${CHANGES}
\`\`\`"

log "Sending to claude for review..."
START_TIME=$(date +%s)

timeout "${TIMEOUT}" "$CC_BIN" -p --dangerously-skip-permissions "$PROMPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 124 ]; then
  log "ERROR: Review timed out after ${TIMEOUT}s"
  exit 1
fi

log "Review completed in ${ELAPSED}s (exit code: ${EXIT_CODE})"
