#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <claude_path>]"
  echo "  --cc <path>    Path to claude CLI (default: claude)"
  echo ""
  echo "Run in a git repo. Generates commit message (type emoji: desc) and creates PR."
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

"$CC_BIN" -p --dangerously-skip-permissions "$PROMPT"
