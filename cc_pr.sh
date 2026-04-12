#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <config_path>] [--timeout <seconds>]"
  echo "  --cc <path>       Claude config directory (default: ~/.claude/lemon)"
  echo "  --timeout <sec>   Timeout in seconds (default: 600)"
  echo ""
  echo "Run in a git repo. Generates commit (type emoji: desc), pushes, and creates PR."
  exit 1
}

CC_CONFIG="$HOME/.claude/lemon"
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --cc) CC_CONFIG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting PR creation..."
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

PROMPT="根据以下 git diff，请执行以下步骤（全程使用中文输出日志和说明）：

1. 生成 commit message，严格遵循以下格式：
   type emoji: 描述（描述用英文）
   
   type 取值及对应 emoji：
   - feat ✨: 新功能
   - fix 🐛: 修复 bug
   - docs 📝: 文档
   - style 💄: 格式/样式
   - refactor ♻️: 重构
   - perf ⚡: 性能优化
   - test ✅: 测试
   - chore 🔧: 杂项
   - ci 👷: CI/CD
   - build 📦: 构建系统

2. 用 git add 暂存所有变更
3. 用生成的 commit message 提交
4. 推送到远程仓库
5. 如果 gh cli 可用，创建 PR 并附上清晰的标题和描述

\`\`\`diff
${CHANGES}
\`\`\`"

log "Sending to claude for PR creation..."
START_TIME=$(date +%s)

timeout "${TIMEOUT}" claude -p --dangerously-skip-permissions "$PROMPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 124 ]; then
  log "ERROR: PR creation timed out after ${TIMEOUT}s"
  exit 1
fi

log "PR creation completed in ${ELAPSED}s (exit code: ${EXIT_CODE})"
