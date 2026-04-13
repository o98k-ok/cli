# CLI Tools

一组轻量 shell 脚本，用于测试 LLM API 接口和基于 Claude Code 的 Git 工作流自动化。

## 安装

```bash
./install.sh
```

脚本会自动将当前目录添加到 shell 的 `PATH` 环境变量中（写入 `~/.zshrc` 或 `~/.bash_profile`），然后重新加载即可：

```bash
source ~/.zshrc
```

## 脚本列表

### API 测试

#### `ping_openai.sh`

测试 OpenAI 格式的 HTTP 接口，发送带 tool_call 的请求。

```bash
./ping_openai.sh <base_url> <api_key> <model>

# 示例
./ping_openai.sh https://api.openai.com/v1 sk-xxx gpt-4o-mini
```

#### `ping_claude.sh`

测试 Claude 格式的 HTTP 接口，发送带 tool_call 的请求。

```bash
./ping_claude.sh <base_url> <api_key> <model>

# 示例
./ping_claude.sh https://api.anthropic.com sk-xxx claude-sonnet-4-20250514
```

### Git 工作流（基于 Claude Code）

以下脚本需要 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 已安装。

通用参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--cc <path>` | Claude config 目录 | `~/.claude/lemon` |
| `--timeout <sec>` | 超时时间（秒） | 因脚本而异 |

#### `cc_review.sh`

对当前仓库未提交/未追踪的变更进行代码审查，输出中文结构化结果。

```bash
./cc_review.sh
./cc_review.sh --cc ~/.claude/cat --timeout 120
```

#### `cc_pr.sh`

自动生成 commit（格式：`type emoji: desc`）、推送并创建 PR。  
如果当前在 `main`/`master` 分支，会自动创建 feature 分支。

```bash
./cc_pr.sh
./cc_pr.sh --cc ~/.claude/cat --timeout 900
```

#### `cc_safe.sh`

安全扫描，检查变更中是否存在密钥泄露、敏感文件、环境变量暴露等安全风险。

```bash
./cc_safe.sh
./cc_safe.sh --timeout 120
```

检查项包括：
- 密钥 / Token / 密码硬编码
- 私钥文件（.pem, .key, id_rsa 等）
- .env 文件及敏感配置
- 数据库连接字符串中的明文凭证
- 内网地址、云服务凭证
- 不安全的文件权限
- 日志中的敏感信息

## 依赖

| 工具 | 用途 | 必需 |
|------|------|------|
| `curl` | API 测试脚本 | ping_*.sh |
| `jq` | JSON 格式化输出 | ping_*.sh |
| `claude` | Claude Code CLI | cc_*.sh |
| `gh` | GitHub CLI（创建 PR） | cc_pr.sh（可选） |
| `git` | 版本控制 | cc_*.sh |

## License

MIT
