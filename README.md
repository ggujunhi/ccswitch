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
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux%20|%20WSL-lightgrey.svg)](#platform-support)

CC-Switcher is a multi-provider launcher for the Claude CLI. It creates lightweight launcher scripts that configure environment variables so you can seamlessly switch between Anthropic, Z.AI, OpenRouter, local models, and many other providers.

Forked from [Clother](https://github.com/jolehuit/clother) with bug fixes, WSL support improvements, and automatic migration.

## Installation

```bash
# 1. Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# 2. Install CC-Switcher
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash
```

## Quick Start

```bash
cc-switcher-native                          # Use your Claude Pro/Team subscription
cc-switcher-zai                             # Z.AI (GLM-5)
cc-switcher-ollama --model qwen3-coder      # Local with Ollama
cc-switcher config                          # Configure providers
```

## Providers

### Cloud

| Command | Provider | Model | API Key |
|---------|----------|-------|---------|
| `cc-switcher-native` | Anthropic | Claude | Your subscription |
| `cc-switcher-zai` | Z.AI | GLM-5 | [z.ai](https://z.ai) |
| `cc-switcher-minimax` | MiniMax | MiniMax-M2.5 | [minimax.io](https://minimax.io) |
| `cc-switcher-kimi` | Kimi | kimi-k2.5 | [kimi.com](https://kimi.com) |
| `cc-switcher-moonshot` | Moonshot AI | kimi-k2.5 | [moonshot.ai](https://moonshot.ai) |
| `cc-switcher-deepseek` | DeepSeek | deepseek-chat | [deepseek.com](https://platform.deepseek.com) |
| `cc-switcher-mimo` | Xiaomi MiMo | mimo-v2-flash | [xiaomimimo.com](https://platform.xiaomimimo.com) |

### OpenRouter (100+ Models)

Access Grok, Gemini, Mistral and more via [openrouter.ai](https://openrouter.ai).

```bash
cc-switcher config openrouter               # Set API key + add models
cc-switcher-or-kimi-k2                      # Use it
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

### China Endpoints

| Command | Endpoint |
|---------|----------|
| `cc-switcher-zai-cn` | open.bigmodel.cn |
| `cc-switcher-minimax-cn` | api.minimaxi.com |
| `cc-switcher-ve` | ark.cn-beijing.volces.com |

### Local (No API Key)

| Command | Provider | Port | Setup |
|---------|----------|------|-------|
| `cc-switcher-ollama` | Ollama | 11434 | [ollama.com](https://ollama.com) |
| `cc-switcher-lmstudio` | LM Studio | 1234 | [lmstudio.ai](https://lmstudio.ai) |
| `cc-switcher-llamacpp` | llama.cpp | 8000 | [github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) |

```bash
# Ollama
ollama pull qwen3-coder && ollama serve
cc-switcher-ollama --model qwen3-coder

# LM Studio
cc-switcher-lmstudio --model <model>

# llama.cpp
./llama-server --model model.gguf --port 8000 --jinja
cc-switcher-llamacpp --model <model>
```

### Custom

```bash
cc-switcher config                          # Choose "custom"
cc-switcher-myprovider                      # Ready
```

## Commands

| Command | Description |
|---------|-------------|
| `cc-switcher config [provider]` | Configure provider |
| `cc-switcher list` | List profiles |
| `cc-switcher test` | Test connectivity |
| `cc-switcher status` | Installation status |
| `cc-switcher uninstall` | Remove everything |

## Changing the Default Model

Each provider launcher comes with a default model (e.g. `glm-5` for Z.AI). You can override it in several ways:

```bash
# One-time: use --model flag
cc-switcher-zai --model glm-4.7

# Permanent: set ANTHROPIC_MODEL in your shell profile (.zshrc / .bashrc)
export ANTHROPIC_MODEL="glm-4.7"
cc-switcher-zai

# Or edit the launcher directly
nano ~/bin/cc-switcher-zai    # Replace the model name on all relevant lines
```

> **Tip**: The `--model` flag is passed directly to Claude CLI and takes priority over everything else.

## How It Works

CC-Switcher creates launcher scripts that set environment variables:

```bash
# cc-switcher-zai does:
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
exec claude "$@"
```

API keys stored in `~/.local/share/cc-switcher/secrets.env` (chmod 600).

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CC_SWITCHER_CONFIG_DIR` | Config directory | `~/.config/cc-switcher` |
| `CC_SWITCHER_DATA_DIR` | Data directory | `~/.local/share/cc-switcher` |
| `CC_SWITCHER_CACHE_DIR` | Cache directory | `~/.cache/cc-switcher` |
| `CC_SWITCHER_BIN` | Binary/launcher directory | `~/.local/bin` (Linux), `~/bin` (macOS) |
| `CC_SWITCHER_VERBOSE` | Enable verbose output | `0` |
| `CC_SWITCHER_DEBUG` | Enable debug output | `0` |
| `CC_SWITCHER_QUIET` | Minimal output | `0` |
| `CC_SWITCHER_YES` | Auto-confirm prompts | `0` |
| `CC_SWITCHER_NO_INPUT` | Non-interactive mode | `0` |
| `CC_SWITCHER_NO_BANNER` | Hide ASCII banner | `0` |
| `CC_SWITCHER_OUTPUT_FORMAT` | Output format (`human`, `json`, `plain`) | `human` |
| `CC_SWITCHER_DEFAULT_PROVIDER` | Default provider to use | (none) |

## Install Directory

By default, CC-Switcher installs launchers to:
- **macOS**: `~/bin`
- **Linux/WSL**: `~/.local/bin` (XDG standard)

You can override this with `--bin-dir` or the `CC_SWITCHER_BIN` environment variable:

```bash
# Using --bin-dir flag
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash -s -- --bin-dir ~/.local/bin

# Using environment variable
export CC_SWITCHER_BIN="$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/ggujunhi/cc-switcher/main/cc-switcher.sh | bash
```

Make sure the chosen directory is in your `PATH`.

## Migration from Clother

CC-Switcher automatically detects existing Clother installations and migrates:

- **Secrets**: API keys from `~/.local/share/clother/secrets.env` are copied with `CLOTHER_*` prefixes renamed to `CC_SWITCHER_*`
- **Config**: Configuration files from `~/.config/clother/` are copied over
- **Environment variables**: `CLOTHER_CONFIG_DIR`, `CLOTHER_DATA_DIR`, `CLOTHER_CACHE_DIR`, and `CLOTHER_BIN` are still recognized with a deprecation warning

Migration is non-destructive -- your original Clother files are preserved. You can remove them manually or by running `clother uninstall` on the old installation.

## VS Code Integration

To use CC-Switcher with the official **Claude Code** extension:

1. Open VS Code Settings (`Cmd+,` or `Ctrl+,`).
2. Search for **"Claude Process Wrapper"** (`claudeProcessWrapper`).
3. Set it to the **full path** of your chosen launcher:
   - macOS: `/Users/yourname/bin/cc-switcher-zai`
   - Linux: `/home/yourname/.local/bin/cc-switcher-zai`
4. Reload VS Code.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `claude: command not found` | Install Claude CLI first |
| `cc-switcher: command not found` | Add your bin directory to PATH (see [Install Directory](#install-directory)) |
| `API key not set` | Run `cc-switcher config` |

## Platform Support

macOS (zsh/bash) -- Linux (zsh/bash) -- Windows (WSL)

## License

MIT (c) 2024-2025 [ggujunhi](https://github.com/ggujunhi)

See [LICENSE](LICENSE) for the full text.
