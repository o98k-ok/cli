#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <claude_path>]"
  echo "  --cc <path>    Path to claude CLI (default: claude)"
  echo ""
  echo "Run in a git repo. Reviews uncommitted changes or last commit diff."
  exit 1
}

CC_BIN="claude"

while [ $# -gt 0 ]; do
  case "$1" in
    --cc) CC_BIN="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if ! command -v "$CC_BIN" &>/dev/null; then
  echo "Error: claude CLI not found at '${CC_BIN}'"
  exit 1
fi

CHANGES=""

# Staged changes
STAGED=$(git diff --cached 2>/dev/null)
[ -n "$STAGED" ] && CHANGES+="=== Staged Changes ===
${STAGED}

"

# Unstaged tracked file changes
UNSTAGED=$(git diff 2>/dev/null)
[ -n "$UNSTAGED" ] && CHANGES+="=== Unstaged Changes ===
${UNSTAGED}

"

# Untracked new files - show full content
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)
if [ -n "$UNTRACKED" ]; then
  UNTRACKED_CONTENT="=== Untracked Files ===
"
  while IFS= read -r f; do
    UNTRACKED_CONTENT+="--- /dev/null
+++ b/${f}
$(sed 's/^/+/' "$f" 2>/dev/null)

"
  done <<< "$UNTRACKED"
  CHANGES+="$UNTRACKED_CONTENT"
fi

if [ -z "$CHANGES" ]; then
  echo "Error: No changes found (no staged, unstaged, or untracked files)"
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

"$CC_BIN" -p --dangerously-skip-permissions "$PROMPT"
