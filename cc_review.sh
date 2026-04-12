#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <config_path>] [--timeout <seconds>]"
  echo "  --cc <path>       Claude config directory (default: ~/.claude/lemon)"
  echo "  --timeout <sec>   Timeout in seconds (default: 300)"
  echo ""
  echo "Run in a git repo. Reviews uncommitted/untracked changes."
  exit 1
}

CC_CONFIG="$HOME/.claude/lemon"
TIMEOUT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --cc) CC_CONFIG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting code review..."
log "Config: ${CC_CONFIG}, Timeout: ${TIMEOUT}s"

if [ ! -d "$CC_CONFIG" ]; then
  log "ERROR: Config directory not found: ${CC_CONFIG}"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  log "ERROR: claude CLI not found in PATH"
  exit 1
fi

export CLAUDE_CONFIG_DIR="$CC_CONFIG"

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

PROMPT="你是一位资深代码审查专家。请仔细审查以下 git diff，全程使用中文输出。

重点关注：
1. Bug 和逻辑错误
2. 安全问题
3. 性能问题
4. 代码风格和可读性
5. 遗漏的边界情况

请以结构化格式输出审查结果，标注严重级别（严重/警告/建议）。

\`\`\`diff
${CHANGES}
\`\`\`"

log "Sending to claude for review..."
START_TIME=$(date +%s)

timeout "${TIMEOUT}" claude -p --dangerously-skip-permissions "$PROMPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 124 ]; then
  log "ERROR: Review timed out after ${TIMEOUT}s"
  exit 1
fi

log "Review completed in ${ELAPSED}s (exit code: ${EXIT_CODE})"
