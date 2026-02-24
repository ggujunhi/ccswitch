#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Configuration Management
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains configuration commands: config (interactive and provider-specific).
#
# Requires: lib/core.sh (for VERSION, BIN_DIR, draw_box, draw_separator, etc.)
#           lib/utils.sh (for logging, colors, prompts, confirm)
#           lib/validation.sh (for validation functions)
#           lib/secrets.sh (for secret management, save_secret, load_secrets)
#           commands/models.sh (for get_provider_def, is_provider_configured)
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

# Source lib files
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# Get the parent of commands/ (i.e., src/)
CCSWITCH_DIR="${CCSWITCH_DIR:-$(dirname "$SCRIPT_DIR")}"

# Source core.sh
if [[ -z "${CCSWITCH_CORE_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/core.sh"
fi

# Source utils.sh
if [[ -z "${CCSWITCH_UTILS_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/utils.sh"
fi

# Source validation.sh
if [[ -z "${CCSWITCH_VALIDATION_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/validation.sh"
fi

# Source secrets.sh
if [[ -z "${CCSWITCH_SECRETS_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/secrets.sh"
fi

# Source models.sh for provider definitions
if [[ -z "${CCSWITCH_COMMANDS_MODELS_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/commands/models.sh"
fi

readonly CCSWITCH_COMMANDS_CONFIG_LOADED=1

# =============================================================================
# HELP SYSTEM
# =============================================================================

show_version() {
  echo "CCSwitch v$VERSION"
}

show_brief_help() {
  cat << EOF
${BOLD}CCSwitch v$VERSION${NC} - Multi-provider launcher for Claude CLI

${BOLD}Usage:${NC} ccswitch [options] <command>

${BOLD}Commands:${NC}
  config       Configure a provider
  default      Set default provider for 'claude'
  keys         Manage API keys (list/set/delete)
  models       Manage provider models (list/update/pin)
  list         List profiles
  info <name>  Provider details
  test         Test providers
  update       Check for updates
  help         Show full help

${BOLD}Examples:${NC}
  ${GREEN}ccswitch config${NC}       Setup a provider
  ${GREEN}ccswitch-zai${NC}          Use Z.AI

Run ${CYAN}ccswitch --help${NC} for full documentation.
EOF
}

show_full_help() {
  cat << EOF
${BOLD}CCSwitch v$VERSION${NC}
Multi-provider launcher for Claude CLI

${BOLD}USAGE${NC}
  ccswitch [options] <command> [args]

${BOLD}EXAMPLES${NC}
  ${GREEN}ccswitch config${NC}                 # Interactive provider setup
  ${GREEN}ccswitch config zai${NC}             # Configure specific provider
  ${GREEN}ccswitch list${NC}                   # Show all profiles
  ${GREEN}ccswitch list --json${NC}            # Machine-readable output
  ${GREEN}ccswitch test${NC}                   # Verify all providers
  ${GREEN}ccswitch-zai${NC}                    # Launch Claude with Z.AI
  ${GREEN}ccswitch-or-gpt4o${NC}               # Launch with OpenRouter GPT-4o

${BOLD}COMMANDS${NC}
  config [provider]    Configure a provider (interactive if no provider given)
  keys                 List all API keys (masked)
  keys set <provider>  Set/update an API key
  keys delete <prov>   Delete an API key
  models               Show current models per provider
  models update        Fetch latest model registry
  models apply         Regenerate launchers with latest models
  models diff          Compare hardcoded vs registry vs pinned
  models pin <p> <m>   Pin provider to a specific model
  models unpin <p>     Remove pin, revert to latest
  list                 List all configured profiles
  info <provider>      Show details for a provider
  test [provider]      Test provider connectivity
  default [provider]   Set default provider for 'claude' command
  status               Show current CCSwitch state
  update               Check for and install updates
  uninstall            Remove CCSwitch completely
  help [command]       Show help (contextual if command given)

${BOLD}OPTIONS${NC}
  -h, --help           Show help
  -V, --version        Show version
  -v, --verbose        Verbose output
  -d, --debug          Debug mode
  -q, --quiet          Minimal output
  -y, --yes            Auto-confirm prompts
  --bin-dir <path>     Set install directory (default: ~/.local/bin on Linux, ~/bin on macOS)
  --no-input           Non-interactive mode (for scripts)
  --no-color           Disable colors
  --no-banner          Hide ASCII banner
  --json               JSON output
  --plain              Plain text output

${BOLD}PROVIDERS${NC}
  ${DIM}Native${NC}
    native             Anthropic direct (no config needed)

  ${DIM}China${NC}
    zai-cn             Z.AI China (GLM-5)
    minimax-cn         MiniMax China (M2.5)
    ve                 VolcEngine (Doubao)

  ${DIM}International${NC}
    zai                Z.AI (GLM-5)
    minimax            MiniMax (M2.5)
    kimi               Kimi (K2.5)
    moonshot           Moonshot AI
    deepseek           DeepSeek
    mimo               Xiaomi MiMo

  ${DIM}Local${NC}
    ollama             Ollama (localhost:11434)
    lmstudio           LM Studio (localhost:1234)
    llamacpp           llama.cpp (localhost:8000)

  ${DIM}Advanced${NC}
    openrouter         100+ models via native API
    custom             Anthropic-compatible endpoint

${BOLD}ENVIRONMENT${NC}
  CCSWITCH_CONFIG_DIR   Config directory (default: ~/.config/ccswitch)
  CCSWITCH_DATA_DIR     Data directory (default: ~/.local/share/ccswitch)
  CCSWITCH_BIN          Binary directory (default: ~/.local/bin on Linux, ~/bin on macOS)
  CCSWITCH_DEFAULT_PROVIDER  Default provider to use
  CCSWITCH_VERBOSE      Enable verbose mode (1)
  CCSWITCH_QUIET        Enable quiet mode (1)
  CCSWITCH_NO_UPDATE    Disable auto-update check (1)
  CCSWITCH_YES          Auto-confirm prompts (1)
  NO_COLOR             Disable colors (standard)

${BOLD}FILES${NC}
  ~/.config/ccswitch/config       User configuration
  ~/.local/share/ccswitch/secrets.env  API keys (chmod 600)
  \$BIN_DIR/ccswitch-*             Provider launchers (see --bin-dir)

${DIM}Documentation: $CCSWITCH_DOCS${NC}
EOF
}

show_command_help() {
  local cmd="$1"
  case "$cmd" in
    config)
      cat << EOF
${BOLD}ccswitch config${NC} - Configure a provider

${BOLD}USAGE${NC}
  ccswitch config              # Interactive menu
  ccswitch config <provider>   # Configure specific provider

${BOLD}EXAMPLES${NC}
  ${GREEN}ccswitch config${NC}              # Show provider menu
  ${GREEN}ccswitch config zai${NC}          # Configure Z.AI
  ${GREEN}ccswitch config openrouter${NC}   # Configure OpenRouter

${BOLD}PROVIDERS${NC}
  native, zai, zai-cn, minimax, minimax-cn, kimi,
  moonshot, ve, deepseek, mimo, ollama, lmstudio,
  llamacpp, openrouter, custom
EOF
      ;;
    list)
      cat << EOF
${BOLD}ccswitch list${NC} - List configured profiles

${BOLD}USAGE${NC}
  ccswitch list [options]

${BOLD}OPTIONS${NC}
  --json    Output as JSON
  --plain   Plain text (for scripts)

${BOLD}EXAMPLES${NC}
  ${GREEN}ccswitch list${NC}                # Human-readable
  ${GREEN}ccswitch list --json${NC}         # For scripting
  ${GREEN}ccswitch list | grep zai${NC}     # Filter
EOF
      ;;
    default)
      cat << EOF
${BOLD}ccswitch default${NC} - Set default provider for 'claude' command

${BOLD}USAGE${NC}
  ccswitch default                       # Show current default
  ccswitch default <provider>            # Shell hook (interactive shells only)
  ccswitch default --force <provider>    # Wrap claude binary (ALL contexts)
  ccswitch default -f -b <provider>      # Wrap + bypass permissions
  ccswitch default reset                 # Restore everything

${BOLD}FLAGS${NC}
  --force, -f    Replace claude binary with routing wrapper
  --bypass, -b   Set bypassPermissions in ~/.claude/settings.json

${BOLD}MODES${NC}
  ${DIM}Hook (default):${NC}   Shell function in .bashrc/.zshrc. Only interactive shells.
  ${DIM}Force (--force):${NC}  Replaces claude binary with wrapper. Works everywhere
                    including OMC agents, subprocesses, and scripts.
  ${DIM}Bypass (--bypass):${NC} Auto-approve all tool calls (deny list still enforced).

${BOLD}EXAMPLES${NC}
  ${GREEN}ccswitch default zai${NC}              # Hook mode
  ${GREEN}ccswitch default --force zai${NC}      # Force mode (OMC compatible)
  ${GREEN}ccswitch default -f -b zai${NC}        # Force + bypass (full auto)
  ${GREEN}ccswitch default reset${NC}            # Restore native + permissions

${BOLD}NOTES${NC}
  Force mode backs up claude as 'claude-original' and creates a wrapper.
  Bypass mode backs up settings.json and restores on reset.
  Per-session override: ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}
EOF
      ;;
    *)
      show_full_help
      ;;
  esac
}

# Command suggestion (prefix/substring match)
suggest_command() {
  local input="$1"
  local -a commands=(config list info test status default uninstall help)
  local best="" best_score=0

  for cmd in "${commands[@]}"; do
    local score=0

    if [[ "$cmd" == "$input"* ]]; then
      # Prefix match: score = 100 + remaining length (shorter is better)
      local remaining=$(( ${#cmd} - ${#input} ))
      score=$(( 100 + remaining ))
    elif [[ "$cmd" == *"$input"* ]]; then
      # Substring match: score = 10 + total length (shorter is better)
      score=$(( 10 + ${#cmd} ))
    fi

    if [[ $score -gt 0 && $score -gt $best_score ]]; then
      best="$cmd"
      best_score=$score
    fi
  done

  [[ -n "$best" ]] && echo "$best"
}

# =============================================================================
# COMMANDS
# =============================================================================

cmd_config() {
  local provider="${1:-}"

  load_secrets
  migrate_from_clother

  if [[ -n "$provider" ]]; then
    case "$provider" in
      openrouter) config_openrouter; return ;;
      custom)     config_custom; return ;;
      ollama|lmstudio|llamacpp) config_local_provider "$provider"; return ;;
      *)          config_provider "$provider"; return ;;
    esac
  fi

  # Interactive menu
  echo
  draw_box "CCSWITCH CONFIGURATION" 54
  echo

  # Count configured
  local configured=0
  for p in native zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo ollama lmstudio llamacpp; do
    is_provider_configured "$p" && ((++configured)) || true
  done
  echo -e "${DIM}$configured providers configured${NC}"
  echo

  # Native
  echo -e "${BOLD}NATIVE${NC}"
  printf "  ${CYAN}%-2s${NC} %-12s %-24s %s\n" "1" "native" "Anthropic direct" \
    "$(is_provider_configured native && echo "${GREEN}${SYM_CHECK}${NC}" || echo "${DIM}${SYM_UNCHECK}${NC}")"
  echo

  # China
  echo -e "${BOLD}CHINA${NC}"
  local -a china_providers=(zai-cn minimax-cn ve)
  local -a china_names=("Z.AI China" "MiniMax China" "VolcEngine")
  for i in "${!china_providers[@]}"; do
    local p="${china_providers[$i]}"
    local status; is_provider_configured "$p" && status="${GREEN}${SYM_CHECK}${NC}" || status="${DIM}${SYM_UNCHECK}${NC}"
    printf "  ${CYAN}%-2s${NC} %-12s %-24s %s\n" "$((i+2))" "$p" "${china_names[$i]}" "$status"
  done
  echo

  # International
  echo -e "${BOLD}INTERNATIONAL${NC}"
  local -a intl_providers=(zai minimax kimi moonshot deepseek mimo)
  local -a intl_names=("Z.AI" "MiniMax" "Kimi K2" "Moonshot AI" "DeepSeek" "Xiaomi MiMo")
  for i in "${!intl_providers[@]}"; do
    local p="${intl_providers[$i]}"
    local status; is_provider_configured "$p" && status="${GREEN}${SYM_CHECK}${NC}" || status="${DIM}${SYM_UNCHECK}${NC}"
    printf "  ${CYAN}%-2s${NC} %-12s %-24s %s\n" "$((i+5))" "$p" "${intl_names[$i]}" "$status"
  done
  echo

  # Local
  echo -e "${BOLD}LOCAL${NC}"
  local -a local_providers=(ollama lmstudio llamacpp)
  local -a local_names=("Ollama" "LM Studio" "llama.cpp")
  for i in "${!local_providers[@]}"; do
    local p="${local_providers[$i]}"
    local status; is_provider_configured "$p" && status="${GREEN}${SYM_CHECK}${NC}" || status="${DIM}${SYM_UNCHECK}${NC}"
    printf "  ${CYAN}%-2s${NC} %-12s %-24s %s\n" "$((i+11))" "$p" "${local_names[$i]}" "$status"
  done
  echo

  # Advanced
  echo -e "${BOLD}ADVANCED${NC}"
  printf "  ${CYAN}%-2s${NC} %-12s %-24s\n" "14" "openrouter" "100+ models (native API)"
  printf "  ${CYAN}%-2s${NC} %-12s %-24s\n" "15" "custom" "Anthropic-compatible"
  echo

  draw_separator 54
  echo -e "  ${DIM}[t] Test providers  [q] Quit${NC}"
  echo

  local choice
  prompt "Choose" "q" choice

  case "$choice" in
    1)  config_provider "native" ;;
    2)  config_provider "zai-cn" ;;
    3)  config_provider "minimax-cn" ;;
    4)  config_provider "ve" ;;
    5)  config_provider "zai" ;;
    6)  config_provider "minimax" ;;
    7)  config_provider "kimi" ;;
    8)  config_provider "moonshot" ;;
    9)  config_provider "deepseek" ;;
    10) config_provider "mimo" ;;
    11) config_local_provider "ollama" ;;
    12) config_local_provider "lmstudio" ;;
    13) config_local_provider "llamacpp" ;;
    14) config_openrouter ;;
    15) config_custom ;;
    t|T) cmd_test ;;
    q|Q) log "Cancelled" ;;
    *)  error "Invalid choice: $choice" ;;
  esac
}

config_provider() {
  local provider="$1"
  local def; def=$(get_provider_def "$provider")

  if [[ -z "$def" ]]; then
    error "Unknown provider: $provider"
    local suggestion; suggestion=$(suggest_command "$provider")
    [[ -n "$suggestion" ]] && echo -e "Did you mean: ${GREEN}$suggestion${NC}?"
    return 1
  fi

  IFS='|' read -r keyvar baseurl model model_opts description <<< "$def"

  echo
  echo -e "${BOLD}Configure: $description${NC}"
  [[ -n "$baseurl" ]] && echo -e "${DIM}Endpoint: $baseurl${NC}"
  echo

  # Native needs no config
  if [[ -z "$keyvar" ]]; then
    success "Native Anthropic is ready"
    suggest_next "Use it: ${GREEN}ccswitch-native${NC}"
    return 0
  fi

  # Show current key if set
  [[ -n "${!keyvar:-}" ]] && echo -e "Current key: ${DIM}$(mask_key "${!keyvar}")${NC}"

  local key
  prompt_secret "API Key" key
  validate_api_key "$key" "$provider" || return 1

  save_secret "$keyvar" "$key"
  success "API key saved"

  suggest_next \
    "Use it: ${GREEN}ccswitch-$provider${NC}" \
    "Test it: ${GREEN}ccswitch test $provider${NC}"
}

config_openrouter() {
  echo
  echo -e "${BOLD}Configure: OpenRouter${NC}"
  echo -e "${DIM}Access 100+ models via native Anthropic API${NC}"
  echo -e "Get API key: ${CYAN}https://openrouter.ai/keys${NC}"
  echo

  load_secrets

  # Handle API key
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    echo -e "Current key: ${DIM}$(mask_key "$OPENROUTER_API_KEY")${NC}"
    if confirm "Change key?" "n"; then
      local new_key
      prompt_secret "New API Key" new_key
      if [[ -n "$new_key" ]]; then
        validate_api_key "$new_key" "openrouter" || return 0
        save_secret "OPENROUTER_API_KEY" "$new_key"
        success "API key saved"
      fi
    fi
  else
    local new_key
    prompt_secret "API Key" new_key
    if [[ -n "$new_key" ]]; then
      validate_api_key "$new_key" "openrouter" || return 0
      save_secret "OPENROUTER_API_KEY" "$new_key"
      success "API key saved"
    else
      warn "No API key provided"
      return 0
    fi
  fi

  # List existing models
  echo
  echo -e "${BOLD}Configured models:${NC}"
  local found=false
  for f in "$BIN_DIR"/ccswitch-or-*; do
    [[ -x "$f" ]] && { found=true; echo -e "  ${GREEN}$(basename "$f")${NC}"; }
  done
  $found || echo -e "  ${DIM}(none)${NC}"

  # Add new model
  echo
  if confirm "Add a model?"; then
    while true; do
      local model
      prompt "Model ID (e.g. openai/gpt-4o) or 'q'" "" model
      [[ "$model" == "q" || -z "$model" ]] && break

      # Get short name
      local default_name; default_name=$(echo "$model" | sed 's|.*/||' | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
      local name
      prompt "Short name" "$default_name" name
      validate_name "$name" "model name" || continue

      save_secret "OPENROUTER_MODEL_$(echo "$name" | tr '[:lower:]-' '[:upper:]_')" "$model"
      generate_or_launcher "$name" "$model"
      success "Created ${GREEN}ccswitch-or-$name${NC}"
      echo
    done
  fi
}

config_custom() {
  echo
  echo -e "${BOLD}Configure: Custom Provider${NC}"
  echo -e "${DIM}For any Anthropic-compatible endpoint${NC}"
  echo

  local name url key
  prompt "Provider name (lowercase)" "" name
  validate_name "$name" || return 1

  prompt "Base URL" "" url
  validate_url "$url" || return 1

  prompt_secret "API Key" key
  validate_api_key "$key" "custom" || return 1

  local keyvar; keyvar="$(echo "$name" | tr '[:lower:]-' '[:upper:]_')_API_KEY"
  save_secret "$keyvar" "$key"
  save_secret "CCSWITCH_${keyvar}_BASE_URL" "$url"

  generate_launcher "$name" "$keyvar" "$url" "" ""
  success "Created ${GREEN}ccswitch-$name${NC}"
}

config_local_provider() {
  local provider="$1"
  local def; def=$(get_provider_def "$provider")
  IFS='|' read -r keyvar baseurl model _ description <<< "$def"
  local auth_token="${keyvar#@}"  # Remove @ prefix

  echo
  echo -e "${BOLD}Configure: $description${NC}"
  echo -e "${DIM}Endpoint: $baseurl${NC}"
  echo

  case "$provider" in
    ollama)
      echo -e "Ollama serves local models with Anthropic-compatible API."
      echo
      echo -e "${BOLD}Setup:${NC}"
      echo -e "  1. Install Ollama: ${CYAN}https://ollama.com${NC}"
      echo -e "  2. Pull a model: ${GREEN}ollama pull qwen3-coder${NC}"
      echo -e "  3. Start serving: ${GREEN}ollama serve${NC}"
      echo
      echo -e "${BOLD}Recommended models:${NC}"
      echo -e "  ${DIM}${SYM_ARROW}${NC} qwen3-coder"
      echo -e "  ${DIM}${SYM_ARROW}${NC} glm-5"
      echo -e "  ${DIM}${SYM_ARROW}${NC} gpt-oss:20b"
      echo -e "  ${DIM}${SYM_ARROW}${NC} gpt-oss:120b"
      ;;
    lmstudio)
      echo -e "LM Studio runs local models with Anthropic-compatible API."
      echo
      echo -e "${BOLD}Setup:${NC}"
      echo -e "  1. Install LM Studio: ${CYAN}https://lmstudio.ai/download${NC}"
      echo -e "  2. Load a model in the app"
      echo -e "  3. Start the server (port 1234)"
      echo
      echo -e "${BOLD}Usage:${NC}"
      echo -e "  ${GREEN}ccswitch-lmstudio --model <model-name>${NC}"
      ;;
    llamacpp)
      echo -e "llama.cpp's llama-server with Anthropic-compatible API."
      echo
      echo -e "${BOLD}Setup:${NC}"
      echo -e "  1. Build llama.cpp: ${CYAN}https://github.com/ggml-org/llama.cpp${NC}"
      echo -e "  2. Start server:"
      echo -e "     ${GREEN}./llama-server --model <model.gguf> --port 8000 --jinja${NC}"
      echo
      echo -e "${BOLD}Usage:${NC}"
      echo -e "  ${GREEN}ccswitch-llamacpp --model <model-name>${NC}"
      ;;
  esac

  echo

  # Regenerate launcher
  generate_local_launcher "$provider" "$baseurl" "$auth_token" "$model" ""

  success "Ready to use: ${GREEN}ccswitch-$provider${NC}"
  [[ -n "$model" ]] && echo -e "${DIM}Default model: $model${NC}"
}
