# CCSwitch

```
   ____ ____ ____          _ _       _
  / ___/ ___/ ___|_      _(_) |_ ___| |__
 | |  | |   \___ \ \ /\ / / | __/ __| '_ \
 | |__| |___ ___) \ V  V /| | || (__| | | |
  \____\____|____/ \_/\_/ |_|\__\___|_| |_|
```

**One CLI to switch between Claude Code providers instantly.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%204%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux%20|%20WSL-lightgrey.svg)](#platform-support)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)](#)

CCSwitch is a multi-provider launcher for the Claude CLI. It creates lightweight launcher scripts that configure environment variables so you can seamlessly switch between Anthropic, OpenRouter, Ollama, LM Studio, local models, and many other providers.

Forked from [Clother](https://github.com/jolehuit/clother) with bug fixes, WSL/Linux support improvements, and automatic migration.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Quick Install](#quick-install)
  - [WSL (Windows) Install](#wsl-windows-install)
  - [Manual Install](#manual-install)
  - [Verify Installation](#verify-installation)
  - [Uninstall](#uninstall)
- [Quick Start](#quick-start)
- [Commands Reference](#commands-reference)
  - [Help & Version](#help--version)
  - [Configuration](#configuration-1)
  - [Listing Providers](#listing-providers)
  - [Provider Info & Testing](#provider-info--testing)
  - [Model Management](#model-management)
  - [API Key Management](#api-key-management)
  - [Status & Updates](#status--updates)
- [Supported Providers](#supported-providers)
  - [Cloud Providers](#cloud-providers)
  - [OpenRouter](#openrouter)
  - [Local Providers](#local-providers)
  - [Custom Provider](#custom-provider)
- [Project Structure](#project-structure)
  - [Modular Architecture](#modular-architecture)
  - [File Locations](#file-locations)
- [Configuration](#configuration)
  - [Changing the Default Model](#changing-the-default-model)
  - [How It Works](#how-it-works)
- [Environment Variables](#environment-variables)
- [VS Code Integration](#vs-code-integration)
- [Migration from Clother](#migration-from-clother)
- [Troubleshooting](#troubleshooting)
- [Platform Support](#platform-support)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Multi-Provider Support**: Switch between Anthropic, OpenRouter, Ollama, LM Studio, llama.cpp, and custom endpoints
- **Interactive Configuration**: Easy-to-use menu for setting up providers
- **Model Management**: List, update, pin, and unpin models
- **API Key Management**: Secure storage and management of API keys
- **Provider Testing**: Test connectivity to providers before use
- **Automatic Updates**: Self-update capability
- **Migration Support**: Automatic migration from Clother
- **Cross-Platform**: Works on Linux, WSL, and macOS
- **Modular Architecture**: Clean, maintainable codebase

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
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash
```

This will:
1. Check that `claude` CLI is available
2. Create launcher scripts in `~/.local/bin/` (Linux/WSL) or `~/bin/` (macOS)
3. Store the full script in `~/.local/share/ccswitch/`
4. Detect and migrate any existing Clother installation

### WSL (Windows) Install

If you're running WSL on Windows:

```bash
# 1. Make sure Claude CLI is installed inside WSL
which claude || npm install -g @anthropic-ai/claude-code

# 2. Install CCSwitch
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash

# 3. If the installer warns about PATH, add it:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Verify
ccswitch --version
```

> **Note**: CCSwitch runs inside WSL, not in native Windows. Open a WSL terminal (Ubuntu, etc.) to use it.

### Manual Install

If you prefer not to pipe to bash:

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh -o ccswitch.sh

# Review it
less ccswitch.sh

# Run the installer
bash ccswitch.sh
```

### Custom Install Directory

```bash
# Using --bin-dir flag
CCSWITCH_BIN="$HOME/my-bin" \
  curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash

# Or set permanently in your shell profile
echo 'export CCSWITCH_BIN="$HOME/my-bin"' >> ~/.bashrc
```

### Verify Installation

```bash
ccswitch --version      # Should print: CCSwitch v1.0.0
ccswitch status         # Show installation status
ccswitch list           # List available provider launchers
```

### Uninstall

```bash
ccswitch uninstall
```

This removes all CCSwitch files (launchers, config, data). You will be asked to confirm by typing `delete ccswitch`.

---

## Quick Start

```bash
# 1. Configure a provider (interactive menu)
ccswitch config

# 2. Use the launcher
ccswitch-zai                             # Z.AI (GLM-5)
ccswitch-native                          # Anthropic (your Claude subscription)
ccswitch-deepseek                        # DeepSeek
ccswitch-ollama --model qwen3-coder      # Local with Ollama
```

Each launcher is a standalone script -- just run it like you would run `claude`.

---

## Commands Reference

### Help & Version

| Command | Description |
|---------|-------------|
| `ccswitch` | Show brief help |
| `ccswitch --help` | Show full help |
| `ccswitch --version` | Show version information |
| `ccswitch help [command]` | Show help for a specific command |

```bash
# Show brief help
ccswitch

# Show full help
ccswitch --help

# Show version
ccswitch --version

# Show help for a specific command
ccswitch help config
```

### Configuration

| Command | Description |
|---------|-------------|
| `ccswitch config` | Open interactive configuration menu |
| `ccswitch config <provider>` | Configure a specific provider directly |

```bash
# Interactive configuration menu
ccswitch config

# Configure specific provider
ccswitch config openrouter
ccswitch config ollama
ccswitch config anthropic
```

### Listing Providers

| Command | Description |
|---------|-------------|
| `ccswitch list` | List all configured provider launchers |
| `ccswitch list --json` | List providers in JSON format |

```bash
# List all configured launchers
ccswitch list

# JSON output for scripting
ccswitch list --json
```

### Provider Info & Testing

| Command | Description |
|---------|-------------|
| `ccswitch info [provider]` | Show detailed provider information |
| `ccswitch test [provider]` | Test provider connection and authentication |

```bash
# Show provider details
ccswitch info openrouter
ccswitch info ollama

# Test provider connectivity
ccswitch test
ccswitch test openrouter
```

### Model Management

| Command | Description |
|---------|-------------|
| `ccswitch models list` | List available models for configured providers |
| `ccswitch models update` | Update model list from providers |
| `ccswitch models pin <model>` | Pin a model as default |
| `ccswitch models unpin <model>` | Unpin a model |

```bash
# List available models
ccswitch models list

# Update model list
ccswitch models update

# Pin a model as default
ccswitch models pin claude-sonnet-4-20250514

# Unpin a model
ccswitch models unpin claude-sonnet-4-20250514
```

### API Key Management

| Command | Description |
|---------|-------------|
| `ccswitch keys list` | List all stored API keys |
| `ccswitch keys set <provider> <key>` | Set API key for a provider |
| `ccswitch keys delete <provider>` | Delete API key for a provider |

```bash
# List all stored keys
ccswitch keys list

# Set API key
ccswitch keys set openrouter sk-or-v1-xxxxx

# Delete API key
ccswitch keys delete openrouter
```

### Status & Updates

| Command | Description |
|---------|-------------|
| `ccswitch status` | Show installation and provider status |
| `ccswitch update` | Check for and install updates |
| `ccswitch install` | Re-install or update CCSwitch |
| `ccswitch uninstall` | Remove CCSwitch completely |

```bash
# Show status
ccswitch status

# Check for updates
ccswitch update

# Re-install
ccswitch install

# Uninstall
ccswitch uninstall
```

---

## Supported Providers

### Cloud Providers

| Command | Provider | Default Model | API Key |
|---------|----------|---------------|---------|
| `ccswitch-native` | Anthropic (Native) | Claude | Your subscription |
| `ccswitch-zai` | Z.AI | GLM-5 | [z.ai](https://z.ai) |
| `ccswitch-minimax` | MiniMax | MiniMax-M2.5 | [minimax.io](https://minimax.io) |
| `ccswitch-kimi` | Kimi | kimi-k2.5 | [kimi.com](https://kimi.com) |
| `ccswitch-moonshot` | Moonshot AI | kimi-k2.5 | [moonshot.ai](https://moonshot.ai) |
| `ccswitch-deepseek` | DeepSeek | deepseek-chat | [deepseek.com](https://platform.deepseek.com) |

### OpenRouter

Access Grok, Gemini, Mistral and more via [openrouter.ai](https://openrouter.ai).

```bash
# Configure OpenRouter
ccswitch config openrouter

# Use it
ccswitch-or-kimi-k2
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

### Local Providers

| Command | Provider | Port | Setup |
|---------|----------|------|-------|
| `ccswitch-ollama` | Ollama | 11434 | [ollama.com](https://ollama.com) |
| `ccswitch-lmstudio` | LM Studio | 1234 | [lmstudio.ai](https://lmstudio.ai) |
| `ccswitch-llamacpp` | llama.cpp | 8000 | [github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) |

```bash
# Ollama example
ollama pull qwen3-coder && ollama serve
ccswitch-ollama --model qwen3-coder

# LM Studio example
ccswitch-lmstudio --model <model>

# llama.cpp example
./llama-server --model model.gguf --port 8000 --jinja
ccswitch-llamacpp --model <model>
```

### Custom Provider

Any Anthropic-compatible API endpoint:

```bash
ccswitch config             # Choose "custom"
# Enter: name, API key, base URL, default model
ccswitch-myprovider         # Ready to use
```

---

## Project Structure

### Modular Architecture

CCSwitch has been refactored into a modular structure for better maintainability and extensibility:

```
src/
├── ccswitch              # Main entry point (~100 lines)
├── ccswitch.sh           # Original monolithic file (preserved for compatibility)
├── lib/
│   ├── core.sh           # Constants, XDG directories, global variables
│   ├── utils.sh          # Logging, colors, prompts, UI utilities
│   ├── validation.sh    # Input validation functions
│   └── secrets.sh       # API key storage and management
├── commands/
│   ├── config.sh        # Configuration and help commands
│   ├── list.sh          # List and info commands
│   ├── models.sh        # Model management (list, update, pin, unpin)
│   ├── test.sh          # Provider connectivity testing
│   ├── install.sh       # Install, update, uninstall commands
│   └── default.sh       # Default launcher command
└── providers/           # Provider configurations (in commands/config.sh)
```

**Key Components:**

- **[`ccswitch`](ccswitch)**: Main entry point that sources all modules and handles command routing
- **[`lib/core.sh`](lib/core.sh)**: Core constants and XDG directory handling
- **[`lib/utils.sh`](lib/utils.sh)**: UI utilities, logging, and color functions
- **[`lib/validation.sh`](lib/validation.sh)**: Input validation functions
- **[`lib/secrets.sh`](lib/secrets.sh)**: Secure API key management
- **[`commands/`](commands/)**: Command implementations

### File Locations

| File | Path |
|------|------|
| Launchers | `~/.local/bin/ccswitch-*` (Linux/WSL) or `~/bin/ccswitch-*` (macOS) |
| Secrets | `~/.local/share/ccswitch/secrets.env` |
| Full script | `~/.local/share/ccswitch/ccswitch-full.sh` |
| Banner | `~/.local/share/ccswitch/banner` |
| Config | `~/.config/ccswitch/config` |

---

## Configuration

### Changing the Default Model

Each launcher comes with a default model. Override it in several ways:

```bash
# One-time: use --model flag
ccswitch-zai --model glm-4.7

# Permanent: set ANTHROPIC_MODEL in your shell profile
echo 'export ANTHROPIC_MODEL="glm-4.7"' >> ~/.bashrc

# Or edit the launcher directly
nano ~/.local/bin/ccswitch-zai
```

> **Tip**: The `--model` flag is passed directly to Claude CLI and takes priority over everything else.

### How It Works

CCSwitch creates launcher scripts that set environment variables before running `claude`:

```bash
# What ccswitch-zai does internally:
#!/usr/bin/env bash
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="<your-api-key>"
export ANTHROPIC_MODEL="glm-5"
exec claude "$@"
```

API keys are stored in `~/.local/share/ccswitch/secrets.env` with `chmod 600` (owner-only read/write).

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CCSWITCH_CONFIG_DIR` | Config directory | `~/.config/ccswitch` |
| `CCSWITCH_DATA_DIR` | Data directory | `~/.local/share/ccswitch` |
| `CCSWITCH_CACHE_DIR` | Cache directory | `~/.cache/ccswitch` |
| `CCSWITCH_BIN` | Launcher directory | `~/.local/bin` (Linux) / `~/bin` (macOS) |
| `CCSWITCH_VERBOSE` | Enable verbose output | `0` |
| `CCSWITCH_DEBUG` | Enable debug output | `0` |
| `CCSWITCH_QUIET` | Minimal output | `0` |
| `CCSWITCH_YES` | Auto-confirm prompts | `0` |
| `CCSWITCH_NO_INPUT` | Non-interactive mode | `0` |
| `CCSWITCH_NO_BANNER` | Hide ASCII banner | `0` |
| `CCSWITCH_OUTPUT_FORMAT` | Output format (`human` / `json` / `plain`) | `human` |
| `CCSWITCH_DEFAULT_PROVIDER` | Default provider | (none) |

---

## VS Code Integration

To use CCSwitch with the official **Claude Code** VS Code extension:

1. Open VS Code Settings (`Cmd+,` / `Ctrl+,`).
2. Search for **"Claude Process Wrapper"** (`claudeProcessWrapper`).
3. Set it to the **full path** of your chosen launcher:
   - **Linux/WSL**: `/home/yourname/.local/bin/ccswitch-zai`
   - **macOS**: `/Users/yourname/bin/ccswitch-zai`
4. Reload VS Code.

---

## Migration from Clother

CCSwitch automatically detects existing [Clother](https://github.com/jolehuit/clother) installations and migrates:

- **Secrets**: API keys from `~/.local/share/clother/secrets.env` are copied with `CLOTHER_*` prefixes renamed to `CCSWITCH_*`
- **Config**: Configuration files from `~/.config/clother/` are copied over
- **Environment variables**: `CLOTHER_CONFIG_DIR`, `CLOTHER_DATA_DIR`, `CLOTHER_CACHE_DIR`, and `CLOTHER_BIN` are still recognized with a deprecation warning

Migration is non-destructive -- your original Clother files are preserved. Remove them manually or via `clother uninstall` on the old installation.

### What was fixed from Clother

- **`stat` command order** -- On Linux/WSL, `stat -f` (macOS syntax) was tried first, which succeeded but returned filesystem info instead of file permissions. This caused a "Fixing secrets file permissions" warning on every command. Fixed by trying `stat -c` (Linux) first.
- **Version mismatch** -- Header said v2.7 but constant was v2.8. Unified.
- **Hardcoded version** -- Fallback message had "2.0" hardcoded. Fixed.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `claude: command not found` | Install Claude CLI first: `npm install -g @anthropic-ai/claude-code` |
| `ccswitch: command not found` | Add `~/.local/bin` to PATH (see [WSL Install](#wsl-windows-install)) |
| `API key not set` | Run `ccswitch config <provider>` |
| `Fixing secrets file permissions` warning | You're running an old version. Reinstall: `ccswitch install` |
| Launcher shows wrong model | Edit the launcher directly or use `--model` flag |
| `bash: ccswitch-zai: Permission denied` | Run `chmod +x ~/.local/bin/ccswitch-zai` |

### Reset Everything

```bash
ccswitch uninstall
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash
```

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux (Ubuntu, Debian, Fedora, etc.) | Fully supported | Primary target |
| WSL (Windows Subsystem for Linux) | Fully supported | Tested on WSL2 |
| macOS (zsh/bash) | Fully supported | Requires Bash 4+ via Homebrew for full features |

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue for bugs and feature requests.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/ggujunhi/ccswitch.git
cd ccswitch

# Run locally
./src/ccswitch --help

# Run tests (if available)
./src/ccswitch test
```

---

## License

MIT (c) 2024-2025 [ggujunhi](https://github.com/ggujunhi)

See [LICENSE](LICENSE) for the full text.

---

# 한국어 가이드

## 프로젝트 소개

CCSwitch는 Claude CLI를 위한 다중 프로바이더 런처입니다. Anthropic, OpenRouter, Ollama, LM Studio, 로컬 모델 등 다양한 프로바이더 간을 쉽게 전환할 수 있도록 환경 변수를 구성하는 가벼운 런처 스크립트를 생성합니다.

[Clother](https://github.com/jolehuit/clother)에서 포크되었으며, 버그 수정, WSL/Linux 지원 개선, 자동 마이그레이션 기능이 추가되었습니다.

---

## 기능

- **다중 프로바이더 지원**: Anthropic, OpenRouter, Ollama, LM Studio, llama.cpp 및 커스텀 엔드포인트 간 전환
- **대화형 설정**: 프로바이더 설정을 위한 사용하기 쉬운 메뉴
- **모델 관리**: 사용 가능한 모델 목록 조회, 업데이트, 고정/고정 해제
- **API 키 관리**: API 키의 안전한 저장 및 관리
- **프로바이더 테스트**: 사용 전 프로바이더 연결 테스트
- **자동 업데이트**: 자체 업데이트 기능
- **마이그레이션 지원**: Clotherからの자동 마이그레이션
- **크로스 플랫폼**: Linux, WSL, macOS에서 동작
- **모듈러 아키텍처**: 깔끔하고 유지보수가 용이한 코드베이스

---

## 설치 방법

### 사전 요구사항

1. **Bash 4+** - Linux/WSL에 사전 설치됨. macOS는 Bash 3.2가 기본이므로 Homebrew로 최신 버전 설치 (`brew install bash`).
2. **Claude CLI** - 공식 Claude Code 명령줄 인터페이스.

```bash
# Claude CLI 설치 (아직 없다면)
npm install -g @anthropic-ai/claude-code
```

또는 공식 인스톨러 사용:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

### 빠른 설치

```bash
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash
```

이 명령어는 다음을 수행합니다:
1. `claude` CLI가 사용 가능한지 확인
2. `~/.local/bin/` (Linux/WSL) 또는 `~/bin/` (macOS)에 런처 스크립트 생성
3. 전체 스크립트를 `~/.local/share/ccswitch/`에 저장
4. 기존 Clother 설치 감지 및 마이그레이션

### WSL (Windows) 설치

Windows에서 WSL을 사용하는 경우:

```bash
# 1. WSL 내에 Claude CLI가 설치되어 있는지 확인
which claude || npm install -g @anthropic-ai/claude-code

# 2. CCSwitch 설치
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash

# 3. PATH 경고가 나오면 추가:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. 확인
ccswitch --version
```

> **참고**: CCSwitch는 네이티브 Windows가 아닌 WSL 내부에서 실행됩니다. 사용하려면 WSL 터미널(Ubuntu 등)을 여세요.

### 수동 설치

bash로 파이프하고 싶지 않은 경우:

```bash
# 스크립트 다운로드
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh -o ccswitch.sh

# 확인
less ccswitch.sh

# 인스톨러 실행
bash ccswitch.sh
```

### 사용자 정의 설치 디렉토리

```bash
# --bin-dir 플래그 사용
CCSWITCH_BIN="$HOME/my-bin" \
  curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash

# 또는 셸 프로필에 영구 설정
echo 'export CCSWITCH_BIN="$HOME/my-bin"' >> ~/.bashrc
```

### 설치 확인

```bash
ccswitch --version      # 출력: CCSwitch v1.0.0
ccswitch status         # 설치 상태 표시
ccswitch list           # 사용 가능한 런처 목록
```

### 삭제

```bash
ccswitch uninstall
```

모든 CCSwitch 파일(런처, 설정, 데이터)이 제거됩니다. `delete ccswitch`를 입력하여 확인바랍니다.

---

## 빠른 시작

```bash
# 1. 프로바이더 설정 (대화형 메뉴)
ccswitch config

# 2. 런처 사용
ccswitch-zai                             # Z.AI (GLM-5)
ccswitch-native                          # Anthropic (구독 사용)
ccswitch-deepseek                        # DeepSeek
ccswitch-ollama --model qwen3-coder      # 로컬 Ollama
```

각 런처는 독립 실행형 스크립트입니다 - `claude`를 실행하는 것처럼 사용하세요.

---

## 명령어 참조

### 도움말 및 버전

| 명령어 | 설명 |
|--------|------|
| `ccswitch` | 간략한 도움말 표시 |
| `ccswitch --help` | 전체 도움말 표시 |
| `ccswitch --version` | 버전 정보 표시 |
| `ccswitch help [명령어]` | 특정 명령어에 대한 도움말 표시 |

```bash
# 간략한 도움말 표시
ccswitch

# 전체 도움말 표시
ccswitch --help

# 버전 표시
ccswitch --version

# 특정 명령어 도움말
ccswitch help config
```

### 설정

| 명령어 | 설명 |
|--------|------|
| `ccswitch config` | 대화형 설정 메뉴 열기 |
| `ccswitch config <프로바이더>` | 특정 프로바이더 직접 설정 |

```bash
# 대화형 설정 메뉴
ccswitch config

# 특정 프로바이더 설정
ccswitch config openrouter
ccswitch config ollama
ccswitch config anthropic
```

### 프로바이더 목록

| 명령어 | 설명 |
|--------|------|
| `ccswitch list` | 구성된 모든 프로바이더 런처 나열 |
| `ccswitch list --json` | JSON 형식으로 프로바이더 나열 |

```bash
# 구성된 모든 런처 나열
ccswitch list

# 스크립팅용 JSON 출력
ccswitch list --json
```

### 프로바이더 정보 및 테스트

| 명령어 | 설명 |
|--------|------|
| `ccswitch info [프로바이더]` | 프로바이더 상세 정보 표시 |
| `ccswitch test [프로바이더]` | 프로바이더 연결 및 인증 테스트 |

```bash
# 프로바이더 상세 정보
ccswitch info openrouter
ccswitch info ollama

# 프로바이더 연결 테스트
ccswitch test
ccswitch test openrouter
```

### 모델 관리

| 명령어 | 설명 |
|--------|------|
| `ccswitch models list` | 구성된 프로바이더의 사용 가능한 모델 목록 |
| `ccswitch models update` | 프로바이더에서 모델 목록 업데이트 |
| `ccswitch models pin <모델>` | 모델을 기본으로 고정 |
| `ccswitch models unpin <모델>` | 모델 고정 해제 |

```bash
# 사용 가능한 모델 목록
ccswitch models list

# 모델 목록 업데이트
ccswitch models update

# 모델을 기본으로 고정
ccswitch models pin claude-sonnet-4-20250514

# 모델 고정 해제
ccswitch models unpin claude-sonnet-4-20250514
```

### API 키 관리

| 명령어 | 설명 |
|--------|------|
| `ccswitch keys list` | 저장된 모든 API 키 나열 |
| `ccswitch keys set <프로바이더> <키>` | 프로바이더의 API 키 설정 |
| `ccswitch keys delete <프로바이더>` | 프로바이더의 API 키 삭제 |

```bash
# 저장된 모든 키 나열
ccswitch keys list

# API 키 설정
ccswitch keys set openrouter sk-or-v1-xxxxx

# API 키 삭제
ccswitch keys delete openrouter
```

### 상태 및 업데이트

| 명령어 | 설명 |
|--------|------|
| `ccswitch status` | 설치 및 프로바이더 상태 표시 |
| `ccswitch update` | 업데이트 확인 및 설치 |
| `ccswitch install` | CCSwitch 재설치 또는 업데이트 |
| `ccswitch uninstall` | CCSwitch 완전히 제거 |

```bash
# 상태 표시
ccswitch status

# 업데이트 확인
ccswitch update

# 재설치
ccswitch install

# 제거
ccswitch uninstall
```

---

## 지원되는 프로바이더

### 클라우드 프로바이더

| 명령어 | 프로바이더 | 기본 모델 | API 키 |
|--------|----------|------------|--------|
| `ccswitch-native` | Anthropic (네이티브) | Claude | 구독 |
| `ccswitch-zai` | Z.AI | GLM-5 | [z.ai](https://z.ai) |
| `ccswitch-minimax` | MiniMax | MiniMax-M2.5 | [minimax.io](https://minimax.io) |
| `ccswitch-kimi` | Kimi | kimi-k2.5 | [kimi.com](https://kimi.com) |
| `ccswitch-moonshot` | Moonshot AI | kimi-k2.5 | [moonshot.ai](https://moonshot.ai) |
| `ccswitch-deepseek` | DeepSeek | deepseek-chat | [deepseek.com](https://platform.deepseek.com) |

### OpenRouter

[openrouter.ai](https://openrouter.ai)를 통해 Grok, Gemini, Mistral 등에 액세스합니다.

```bash
# OpenRouter 설정
ccswitch config openrouter

# 사용
ccswitch-or-kimi-k2
```

인기 있는 모델 ID:

| 모델 ID | 설명 |
|---------|------|
| `anthropic/claude-opus-4.6` | Claude Opus 4.6 |
| `z-ai/glm-5` | GLM-5 (Z.AI) |
| `minimax/minimax-m2.5` | MiniMax M2.5 |
| `moonshotai/kimi-k2.5` | Kimi K2.5 |
| `qwen/qwen3-coder-next` | Qwen3 Coder Next |
| `deepseek/deepseek-v3.2-speciale` | DeepSeek V3.2 Speciale |

> **팁**: 모델 ID는 [openrouter.ai/models](https://openrouter.ai/models)에서 찾으세요 - 모델 이름 옆의 복사 아이콘을 클릭하세요.

> 모델이 예상대로 작동하지 않으면 `:exacto` 변형을 사용해 보세요 (예: `moonshotai/kimi-k2-0905:exacto`) - 더 나은 도구 호출 지원을 제공합니다.

### 로컬 프로바이더

| 명령어 | 프로바이더 | 포트 | 설정 |
|--------|----------|------|------|
| `ccswitch-ollama` | Ollama | 11434 | [ollama.com](https://ollama.com) |
| `ccswitch-lmstudio` | LM Studio | 1234 | [lmstudio.ai](https://lmstudio.ai) |
| `ccswitch-llamacpp` | llama.cpp | 8000 | [github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) |

```bash
# Ollama 예시
ollama pull qwen3-coder && ollama serve
ccswitch-ollama --model qwen3-coder

# LM Studio 예시
ccswitch-lmstudio --model <모델>

# llama.cpp 예시
./llama-server --model model.gguf --port 8000 --jinja
ccswitch-llamacpp --model <모델>
```

### 커스텀 프로바이더

모든 Anthropic 호환 API 엔드포인트:

```bash
ccswitch config             # "custom" 선택
# 입력: 이름, API 키, 기본 URL, 기본 모델
ccswitch-myprovider         # 사용 준비 완료
```

---

## 프로젝트 구조

### 모듈러 아키텍처

CCSwitch는 더 나은 유지보수성과 확장성을 위해 모듈러 구조로 재구성되었습니다:

```
src/
├── ccswitch              # 메인 진입점 (~100줄)
├── ccswitch.sh           # 원본 단일 파일 (호환성을 위해 보존)
├── lib/
│   ├── core.sh           # 상수, XDG 디렉토리, 전역 변수
│   ├── utils.sh          # 로깅, 색상, 프롬프트, UI 유틸리티
│   ├── validation.sh     # 입력 검증 함수
│   └── secrets.sh        # API 키 저장 및 관리
├── commands/
│   ├── config.sh         # 설정 및 도움말 명령
│   ├── list.sh           # 목록 및 정보 명령
│   ├── models.sh         # 모델 관리 (목록, 업데이트, 고정, 고정 해제)
│   ├── test.sh           # 프로바이더 연결 테스트
│   ├── install.sh        # 설치, 업데이트, 제거 명령
│   └── default.sh        # 기본 런처 명령
└── providers/            # 프로바이더 설정 (commands/config.sh에 있음)
```

**주요 컴포넌트:**

- **[`ccswitch`](ccswitch)**: 모든 모듈을 소싱하고 명령 라우팅을 처리하는 메인 진입점
- **[`lib/core.sh`](lib/core.sh)**: 핵심 상수 및 XDG 디렉토리 처리
- **[`lib/utils.sh`](lib/utils.sh)**: UI 유틸리티, 로깅, 색상 함수
- **[`lib/validation.sh`](lib/validation.sh)**: 입력 검증 함수
- **[`lib/secrets.sh`](lib/secrets.sh)**: 안전한 API 키 관리
- **[`commands/`](commands/)**: 명령 구현

### 파일 위치

| 파일 | 경로 |
|------|------|
| 런처 | `~/.local/bin/ccswitch-*` (Linux/WSL) 또는 `~/bin/ccswitch-*` (macOS) |
| 시크릿 | `~/.local/share/ccswitch/secrets.env` |
| 전체 스크립트 | `~/.local/share/ccswitch/ccswitch-full.sh` |
| 배너 | `~/.local/share/ccswitch/banner` |
| 설정 | `~/.config/ccswitch/config` |

---

## 설정

### 기본 모델 변경

각 런처에는 기본 모델이 제공됩니다. 여러 가지 방법으로 재정의할 수 있습니다:

```bash
# 일회성: --model 플래그 사용
ccswitch-zai --model glm-4.7

# 영구적: 셸 프로필에서 ANTHROPIC_MODEL 설정
echo 'export ANTHROPIC_MODEL="glm-4.7"' >> ~/.bashrc

# 또는 런처를 직접 편집
nano ~/.local/bin/ccswitch-zai
```

> **팁**: `--model` 플래그가 직접 Claude CLI에 전달되어 모든 것보다 우선합니다.

### 작동 방식

CCSwitch는 `claude`를 실행하기 전에 환경 변수를 설정하는 런처 스크립트를 생성합니다:

```bash
# ccswitch-zai가 내부에서 수행하는 작업:
#!/usr/bin/env bash
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="<your-api-key>"
export ANTHROPIC_MODEL="glm-5"
exec claude "$@"
```

API 키는 `chmod 600`(소유자만 읽기/쓰기)으로 `~/.local/share/ccswitch/secrets.env`에 저장됩니다.

---

## 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `CCSWITCH_CONFIG_DIR` | 설정 디렉토리 | `~/.config/ccswitch` |
| `CCSWITCH_DATA_DIR` | 데이터 디렉토리 | `~/.local/share/ccswitch` |
| `CCSWITCH_CACHE_DIR` | 캐시 디렉토리 | `~/.cache/ccswitch` |
| `CCSWITCH_BIN` | 런처 디렉토리 | `~/.local/bin` (Linux) / `~/bin` (macOS) |
| `CCSWITCH_VERBOSE` | 상세 출력 활성화 | `0` |
| `CCSWITCH_DEBUG` | 디버그 출력 활성화 | `0` |
| `CCSWITCH_QUIET` | 최소 출력 | `0` |
| `CCSWITCH_YES` | 프롬프트 자동 확인 | `0` |
| `CCSWITCH_NO_INPUT` | 비대화형 모드 | `0` |
| `CCSWITCH_NO_BANNER` | ASCII 배너 숨기기 | `0` |
| `CCSWITCH_OUTPUT_FORMAT` | 출력 형식 (`human` / `json` / `plain`) | `human` |
| `CCSWITCH_DEFAULT_PROVIDER` | 기본 프로바이더 | (없음) |

---

## VS Code 통합

공식 **Claude Code** VS Code 확장에서 CCSwitch를 사용하려면:

1. VS Code 설정 열기 (`Cmd+,` / `Ctrl+,`).
2. **"Claude Process Wrapper"** (`claudeProcessWrapper`) 검색.
3. 선택한 런처의 **전체 경로**로 설정:
   - **Linux/WSL**: `/home/yourname/.local/bin/ccswitch-zai`
   - **macOS**: `/Users/yourname/bin/ccswitch-zai`
4. VS Code 다시 로드.

---

## Clother에서 마이그레이션

CCSwitch는 기존 [Clother](https://github.com/jolehuit/clother) 설치를 자동으로 감지하여 마이그레이션합니다:

- **시크릿**: `~/.local/share/clother/secrets.env`의 API 키가 `CLOTHER_*` 접두사가 `CCSWITCH_*`로 이름 변경되어 복사됨
- **설정**: `~/.config/clother/`의 설정 파일이 복사됨
- **환경 변수**: `CLOTHER_CONFIG_DIR`, `CLOTHER_DATA_DIR`, `CLOTHER_CACHE_DIR`, `CLOTHER_BIN`은 비推奨 경고와 함께 계속 인식됨

마이그레이션은 비파괴적입니다 - 원본 Clother 파일은 보존됩니다. 수동으로 또는 이전 설치에서 `clother uninstall`으로 제거하세요.

### Clother에서 수정된 사항

- **`stat` 명령어 순서** -- Linux/WSL에서 `stat -f`(macOS 구문)가 먼저 시도되어 파일 권한 대신 파일 시스템 정보를 반환했습니다. 이로 인해 모든 명령에서 "Fixing secrets file permissions" 경고가 표시되었습니다. `stat -c`(Linux)를 먼저 시도하도록 수정됨.
- **버전 불일치** -- 헤더는 v2.7이라고 하지만 상수는 v2.8이었습니다. 통합됨.
- **하드코딩된 버전** -- 폴백 메시지에 "2.0"이 하드코딩되어 있었습니다. 수정됨.

---

## 문제 해결

| 문제 | 해결 방법 |
|------|----------|
| `claude: command not found` | 먼저 Claude CLI 설치: `npm install -g @anthropic-ai/claude-code` |
| `ccswitch: command not found` | `~/.local/bin`을 PATH에 추가 ([WSL 설치](#wsl-windows-install) 참조) |
| `API key not set` | `ccswitch config <프로바이더>` 실행 |
| `Fixing secrets file permissions` 경고 | 구버전입니다. 재설치: `ccswitch install` |
| 런처가 잘못된 모델 표시 | 런처를 직접 편집하거나 `--model` 플래그 사용 |
| `bash: ccswitch-zai: Permission denied` | `chmod +x ~/.local/bin/ccswitch-zai` 실행 |

### 모든 것 초기화

```bash
ccswitch uninstall
curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh | bash
```

---

## 플랫폼 지원

| 플랫폼 | 상태 | 참고 |
|--------|------|------|
| Linux (Ubuntu, Debian, Fedora 등) | 완전 지원 | 주요 대상 |
| WSL (Windows Subsystem for Linux) | 완전 지원 | WSL2에서 테스트됨 |
| macOS (zsh/bash) | 완전 지원 | 전체 기능을 위해 Homebrew로 Bash 4+ 필요 |

---

## 개발 및 기여

기여는 환영합니다! 버그 및 기능 요청에 대해서는 풀 리퀘스트 또는 이슈를 제출해 주세요.

### 개발 환경 설정

```bash
# 저장소 클론
git clone https://github.com/ggujunhi/ccswitch.git
cd ccswitch

# 로컬 실행
./src/ccswitch --help

# 테스트 실행 (사용 가능한 경우)
./src/ccswitch test
```

---

## 라이선스

MIT (c) 2024-2025 [ggujunhi](https://github.com/ggujunhi)

전체 텍스트는 [LICENSE](LICENSE)를 참조하세요.
