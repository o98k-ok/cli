#!/bin/bash

usage() {
  echo "Usage: $0 [--cc <config_path>] [--timeout <seconds>]"
  echo "  --cc <path>       Claude config directory (default: ~/.claude/lemon)"
  echo "  --timeout <sec>   Timeout in seconds (default: 300)"
  echo ""
  echo "Run in a git repo. Scans uncommitted/untracked changes for security issues."
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

log "Starting security scan..."
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

PROMPT="你是一位安全审计专家。请仔细扫描以下 git diff，全程使用中文输出。

重点检查以下安全风险：
1. **密钥泄露** — API Key、Secret Key、Token、密码等硬编码在代码中
2. **证书/密钥文件** — .pem, .key, .p12, .pfx, .jks, id_rsa 等私钥文件被提交
3. **环境变量泄露** — .env 文件、包含敏感环境变量的配置文件
4. **数据库凭证** — 连接字符串中包含明文用户名密码
5. **内部地址暴露** — 内网 IP、内部域名、调试端口等
6. **敏感配置** — AWS credentials、GCP service account、OAuth client secret 等云服务凭证
7. **不安全的文件权限** — 777 权限、可写配置文件等
8. **日志中的敏感信息** — 打印密码、token 等到日志

输出格式：
- 如果发现问题，按严重级别（🔴 严重 / 🟡 警告 / 🔵 建议）逐条列出，包含文件名、行号和具体问题描述
- 如果没有发现安全问题，输出「✅ 未发现安全风险」
- 最后给出总结和修复建议

\`\`\`diff
${CHANGES}
\`\`\`"

log "Sending to claude for security scan..."
START_TIME=$(date +%s)

timeout "${TIMEOUT}" claude -p --dangerously-skip-permissions "$PROMPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 124 ]; then
  log "ERROR: Security scan timed out after ${TIMEOUT}s"
  exit 1
fi

log "Security scan completed in ${ELAPSED}s (exit code: ${EXIT_CODE})"
