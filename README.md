# CC-Switcher

```
   ____ ____      ____          _ _       _
  / ___/ ___|    / ___|_      _(_) |_ ___| |__   ___ _ __
 | |  | |   ____\___ \ \ /\ / / | __/ __| '_ \ / _ \ '__|
 | |__| |__|_____|__) \ V  V /| | || (__| | | |  __/ |
  \____\____|   |____/ \_/\_/ |_|\__\___|_| |_|\___|_|
```

**One CLI to switch between Claude Code providers instantly.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%204%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux%20|%20WSL-lightgrey.svg)](#platform-support)

CC-Switcher is a multi-provider launcher for the Claude CLI. It creates lightweight launcher scripts that configure environment variables so you can seamlessly switch between Anthropic, Z.AI, OpenRouter, local models, and many other providers.

Forked from [Clother](https://github.com/jolehuit/clother) with bug fixes, WSL/Linux support improvements, and automatic migration.

---

## Table of Contents

- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Quick Install](#quick-install)
  - [WSL (Windows) Install](#wsl-windows-install)
  - [Manual Install](#manual-install)
  - [Verify Installation](#verify-installation)
  - [Uninstall](#uninstall)
- [Quick Start](#quick-start)
- [Providers](#providers)
- [Commands](#commands)
- [Configuration](#configuration)
- [Environment Variables](#environment-variables)
- [Migration from Clother](#migration-from-clother)
- [VS Code Integration](#vs-code-integration)
- [Troubleshooting](#troubleshooting)
- [Platform Support](#platform-support)
- [License](#license)
- [Korean / 한국어 가이드](#한국어-가이드)

---

## Installation

### Prerequisites

1. **Bash 4+** - Pre-installed on Linux/WSL. macOS ships Bash 3.2; install a newer version via Homebrew (`brew install bash`).
2. **Claude CLI** - The official Claude Code command-line interface.

```bash
# Install Claude CLI first (if not already installed)
npm install -g @anthropic-ai/claude-code
```

Or via the official installer:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash
```

This will:
1. Check that `claude` CLI is available
2. Create launcher scripts in `~/.local/bin/` (Linux/WSL) or `~/bin/` (macOS)
3. Store the full script in `~/.local/share/cc-switcher/`
4. Detect and migrate any existing Clother installation

### WSL (Windows) Install

If you're running WSL on Windows:

```bash
# 1. Make sure Claude CLI is installed inside WSL
which claude || npm install -g @anthropic-ai/claude-code

# 2. Install CC-Switcher
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash

# 3. If the installer warns about PATH, add it:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Verify
cc-switcher --version
```

> **Note**: CC-Switcher runs inside WSL, not in native Windows. Open a WSL terminal (Ubuntu, etc.) to use it.

### Manual Install

If you prefer not to pipe to bash:

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh -o cc-switcher.sh

# Review it
less cc-switcher.sh

# Run the installer
bash cc-switcher.sh
```

### Custom Install Directory

```bash
# Using --bin-dir flag
CC_SWITCHER_BIN="$HOME/my-bin" \
  curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash

# Or set permanently in your shell profile
echo 'export CC_SWITCHER_BIN="$HOME/my-bin"' >> ~/.bashrc
```

### Verify Installation

```bash
cc-switcher --version      # Should print: CC-Switcher v1.0.0
cc-switcher status         # Show installation status
cc-switcher list           # List available provider launchers
```

### Uninstall

```bash
cc-switcher uninstall
```

This removes all CC-Switcher files (launchers, config, data). You will be asked to confirm by typing `delete cc-switcher`.

---

## Quick Start

```bash
# 1. Configure a provider (interactive menu)
cc-switcher config

# 2. Use the launcher
cc-switcher-zai                             # Z.AI (GLM-5)
cc-switcher-native                          # Anthropic (your Claude subscription)
cc-switcher-deepseek                        # DeepSeek
cc-switcher-ollama --model qwen3-coder      # Local with Ollama
```

Each launcher is a standalone script -- just run it like you would run `claude`.

---

## Providers

### Cloud

| Command | Provider | Default Model | API Key |
|---------|----------|---------------|---------|
| `cc-switcher-native` | Anthropic | Claude | Your subscription |
| `cc-switcher-zai` | Z.AI | GLM-5 | [z.ai](https://z.ai) |
| `cc-switcher-minimax` | MiniMax | MiniMax-M2.5 | [minimax.io](https://minimax.io) |
| `cc-switcher-kimi` | Kimi | kimi-k2.5 | [kimi.com](https://kimi.com) |
| `cc-switcher-moonshot` | Moonshot AI | kimi-k2.5 | [moonshot.ai](https://moonshot.ai) |
| `cc-switcher-deepseek` | DeepSeek | deepseek-chat | [deepseek.com](https://platform.deepseek.com) |
| `cc-switcher-mimo` | Xiaomi MiMo | mimo-v2-flash | [xiaomimimo.com](https://platform.xiaomimimo.com) |

### China Endpoints

| Command | Endpoint |
|---------|----------|
| `cc-switcher-zai-cn` | open.bigmodel.cn |
| `cc-switcher-minimax-cn` | api.minimaxi.com |
| `cc-switcher-ve` | ark.cn-beijing.volces.com |

### OpenRouter (100+ Models)

Access Grok, Gemini, Mistral and more via [openrouter.ai](https://openrouter.ai).

```bash
# Configure OpenRouter
cc-switcher config openrouter

# Use it
cc-switcher-or-kimi-k2
```

Popular model IDs:

| Model ID | Description |
|----------|-------------|
| `anthropic/claude-opus-4.6` | Claude Opus 4.6 |
| `z-ai/glm-5` | GLM-5 (Z.AI) |
| `minimax/minimax-m2.5` | MiniMax M2.5 |
| `moonshotai/kimi-k2.5` | Kimi K2.5 |
| `qwen/qwen3-coder-next` | Qwen3 Coder Next |
| `deepseek/deepseek-v3.2-speciale` | DeepSeek V3.2 Speciale |

> **Tip**: Find model IDs on [openrouter.ai/models](https://openrouter.ai/models) -- click the copy icon next to any model name.

> If a model doesn't work as expected, try the `:exacto` variant (e.g. `moonshotai/kimi-k2-0905:exacto`) which provides better tool calling support.

### Local (No API Key)

| Command | Provider | Port | Setup |
|---------|----------|------|-------|
| `cc-switcher-ollama` | Ollama | 11434 | [ollama.com](https://ollama.com) |
| `cc-switcher-lmstudio` | LM Studio | 1234 | [lmstudio.ai](https://lmstudio.ai) |
| `cc-switcher-llamacpp` | llama.cpp | 8000 | [github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) |

```bash
# Ollama example
ollama pull qwen3-coder && ollama serve
cc-switcher-ollama --model qwen3-coder

# LM Studio example
cc-switcher-lmstudio --model <model>

# llama.cpp example
./llama-server --model model.gguf --port 8000 --jinja
cc-switcher-llamacpp --model <model>
```

### Custom Provider

Any Anthropic-compatible API endpoint:

```bash
cc-switcher config             # Choose "custom"
# Enter: name, API key, base URL, default model
cc-switcher-myprovider         # Ready to use
```

---

## Commands

| Command | Description |
|---------|-------------|
| `cc-switcher config` | Interactive configuration menu |
| `cc-switcher config <provider>` | Configure a specific provider |
| `cc-switcher config openrouter` | Configure OpenRouter + add models |
| `cc-switcher list` | List all configured launchers |
| `cc-switcher list --json` | List launchers in JSON format |
| `cc-switcher info <provider>` | Show provider details |
| `cc-switcher test [provider]` | Test endpoint connectivity |
| `cc-switcher status` | Show installation status |
| `cc-switcher install` | Re-install / update |
| `cc-switcher uninstall` | Remove CC-Switcher completely |
| `cc-switcher --help` | Show full help |

---

## Configuration

### Changing the Default Model

Each launcher comes with a default model. Override it in several ways:

```bash
# One-time: use --model flag
cc-switcher-zai --model glm-4.7

# Permanent: set ANTHROPIC_MODEL in your shell profile
echo 'export ANTHROPIC_MODEL="glm-4.7"' >> ~/.bashrc

# Or edit the launcher directly
nano ~/.local/bin/cc-switcher-zai
```

> **Tip**: The `--model` flag is passed directly to Claude CLI and takes priority over everything else.

### How It Works

CC-Switcher creates launcher scripts that set environment variables before running `claude`:

```bash
# What cc-switcher-zai does internally:
#!/usr/bin/env bash
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="<your-api-key>"
export ANTHROPIC_MODEL="glm-5"
exec claude "$@"
```

API keys are stored in `~/.local/share/cc-switcher/secrets.env` with `chmod 600` (owner-only read/write).

### File Locations

| File | Path |
|------|------|
| Launchers | `~/.local/bin/cc-switcher-*` (Linux/WSL) or `~/bin/cc-switcher-*` (macOS) |
| Secrets | `~/.local/share/cc-switcher/secrets.env` |
| Full script | `~/.local/share/cc-switcher/cc-switcher-full.sh` |
| Banner | `~/.local/share/cc-switcher/banner` |
| Config | `~/.config/cc-switcher/config` |

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CC_SWITCHER_CONFIG_DIR` | Config directory | `~/.config/cc-switcher` |
| `CC_SWITCHER_DATA_DIR` | Data directory | `~/.local/share/cc-switcher` |
| `CC_SWITCHER_CACHE_DIR` | Cache directory | `~/.cache/cc-switcher` |
| `CC_SWITCHER_BIN` | Launcher directory | `~/.local/bin` (Linux) / `~/bin` (macOS) |
| `CC_SWITCHER_VERBOSE` | Enable verbose output | `0` |
| `CC_SWITCHER_DEBUG` | Enable debug output | `0` |
| `CC_SWITCHER_QUIET` | Minimal output | `0` |
| `CC_SWITCHER_YES` | Auto-confirm prompts | `0` |
| `CC_SWITCHER_NO_INPUT` | Non-interactive mode | `0` |
| `CC_SWITCHER_NO_BANNER` | Hide ASCII banner | `0` |
| `CC_SWITCHER_OUTPUT_FORMAT` | Output format (`human` / `json` / `plain`) | `human` |
| `CC_SWITCHER_DEFAULT_PROVIDER` | Default provider | (none) |

---

## Migration from Clother

CC-Switcher automatically detects existing [Clother](https://github.com/jolehuit/clother) installations and migrates:

- **Secrets**: API keys from `~/.local/share/clother/secrets.env` are copied with `CLOTHER_*` prefixes renamed to `CC_SWITCHER_*`
- **Config**: Configuration files from `~/.config/clother/` are copied over
- **Environment variables**: `CLOTHER_CONFIG_DIR`, `CLOTHER_DATA_DIR`, `CLOTHER_CACHE_DIR`, and `CLOTHER_BIN` are still recognized with a deprecation warning

Migration is non-destructive -- your original Clother files are preserved. Remove them manually or via `clother uninstall` on the old installation.

### What was fixed from Clother

- **`stat` command order** -- On Linux/WSL, `stat -f` (macOS syntax) was tried first, which succeeded but returned filesystem info instead of file permissions. This caused a "Fixing secrets file permissions" warning on every command. Fixed by trying `stat -c` (Linux) first.
- **Version mismatch** -- Header said v2.7 but constant was v2.8. Unified.
- **Hardcoded version** -- Fallback message had "2.0" hardcoded. Fixed.

---

## VS Code Integration

To use CC-Switcher with the official **Claude Code** VS Code extension:

1. Open VS Code Settings (`Cmd+,` / `Ctrl+,`).
2. Search for **"Claude Process Wrapper"** (`claudeProcessWrapper`).
3. Set it to the **full path** of your chosen launcher:
   - **Linux/WSL**: `/home/yourname/.local/bin/cc-switcher-zai`
   - **macOS**: `/Users/yourname/bin/cc-switcher-zai`
4. Reload VS Code.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `claude: command not found` | Install Claude CLI first: `npm install -g @anthropic-ai/claude-code` |
| `cc-switcher: command not found` | Add `~/.local/bin` to PATH (see [WSL Install](#wsl-windows-install)) |
| `API key not set` | Run `cc-switcher config <provider>` |
| `Fixing secrets file permissions` warning | You're running an old version. Reinstall: `cc-switcher install` |
| Launcher shows wrong model | Edit the launcher directly or use `--model` flag |
| `bash: cc-switcher-zai: Permission denied` | Run `chmod +x ~/.local/bin/cc-switcher-zai` |

### Reset Everything

```bash
cc-switcher uninstall
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash
```

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux (Ubuntu, Debian, Fedora, etc.) | Fully supported | Primary target |
| WSL (Windows Subsystem for Linux) | Fully supported | Tested on WSL2 |
| macOS (zsh/bash) | Fully supported | Requires Bash 4+ via Homebrew for full features |

---

## License

MIT (c) 2024-2025 [ggujunhi](https://github.com/ggujunhi)

See [LICENSE](LICENSE) for the full text.

---

## 한국어 가이드

### 설치 방법

**사전 요구사항**: Claude CLI가 설치되어 있어야 합니다.

```bash
# Claude CLI 설치 (아직 없다면)
npm install -g @anthropic-ai/claude-code

# CC-Switcher 설치
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash
```

### WSL (Windows) 사용자

WSL 터미널(Ubuntu 등)에서 실행하세요. 네이티브 Windows CMD/PowerShell에서는 동작하지 않습니다.

```bash
# 1. WSL 터미널을 엽니다

# 2. Claude CLI 확인
which claude || npm install -g @anthropic-ai/claude-code

# 3. CC-Switcher 설치
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash

# 4. PATH 설정 (설치 시 경고가 나오면)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 5. 설치 확인
cc-switcher --version
cc-switcher status
```

### 사용법

```bash
# 프로바이더 설정 (대화형 메뉴)
cc-switcher config

# 프로바이더별 실행
cc-switcher-native                          # Anthropic (구독 사용)
cc-switcher-zai                             # Z.AI (GLM-5)
cc-switcher-deepseek                        # DeepSeek
cc-switcher-ollama --model qwen3-coder      # 로컬 Ollama

# 상태 확인
cc-switcher status                          # 설치 상태
cc-switcher list                            # 사용 가능한 런처 목록
cc-switcher test zai                        # 연결 테스트
```

### Clother에서 마이그레이션

기존에 Clother를 사용하고 있었다면, CC-Switcher 설치 시 자동으로 감지하여 API 키와 설정을 이전합니다. 기존 Clother 파일은 삭제되지 않으므로, 필요 시 `clother uninstall`로 별도 제거하세요.

### 삭제

```bash
cc-switcher uninstall
# "delete cc-switcher" 를 입력하여 확인
```

### 문제 해결

| 문제 | 해결 방법 |
|------|-----------|
| `cc-switcher: command not found` | `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` |
| `claude: command not found` | `npm install -g @anthropic-ai/claude-code` |
| API 키 미설정 | `cc-switcher config <프로바이더>` 실행 |
| 권한 오류 (secrets) | `cc-switcher install` 로 재설치 |
