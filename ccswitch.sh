#!/usr/bin/env bash
# =============================================================================
# CCSWITCH v1.2.0 - Multi-provider launcher for Claude CLI
# =============================================================================
# A CLI tool to manage and switch between different LLM providers
# for the Claude Code command-line interface.
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

set -euo pipefail
IFS=$'\n\t'
umask 077

readonly VERSION="1.2.0"
readonly CCSWITCH_DOCS="https://github.com/ggujunhi/ccswitch"
readonly CCSWITCH_RAW="https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh"
readonly UPDATE_CHECK_INTERVAL=86400  # 24 hours

# =============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# =============================================================================

readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Backward compatibility: support CLOTHER_* env vars with deprecation
if [[ -n "${CLOTHER_CONFIG_DIR:-}" ]] && [[ -z "${CCSWITCH_CONFIG_DIR:-}" ]]; then
  CCSWITCH_CONFIG_DIR="$CLOTHER_CONFIG_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_CONFIG_DIR is deprecated, use CCSWITCH_CONFIG_DIR instead" >&2
fi
if [[ -n "${CLOTHER_DATA_DIR:-}" ]] && [[ -z "${CCSWITCH_DATA_DIR:-}" ]]; then
  CCSWITCH_DATA_DIR="$CLOTHER_DATA_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_DATA_DIR is deprecated, use CCSWITCH_DATA_DIR instead" >&2
fi
if [[ -n "${CLOTHER_CACHE_DIR:-}" ]] && [[ -z "${CCSWITCH_CACHE_DIR:-}" ]]; then
  CCSWITCH_CACHE_DIR="$CLOTHER_CACHE_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_CACHE_DIR is deprecated, use CCSWITCH_CACHE_DIR instead" >&2
fi
if [[ -n "${CLOTHER_BIN:-}" ]] && [[ -z "${CCSWITCH_BIN:-}" ]]; then
  CCSWITCH_BIN="$CLOTHER_BIN"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_BIN is deprecated, use CCSWITCH_BIN instead" >&2
fi

readonly CONFIG_DIR="${CCSWITCH_CONFIG_DIR:-$XDG_CONFIG_HOME/ccswitch}"
readonly DATA_DIR="${CCSWITCH_DATA_DIR:-$XDG_DATA_HOME/ccswitch}"
readonly CACHE_DIR="${CCSWITCH_CACHE_DIR:-$XDG_CACHE_HOME/ccswitch}"

# Default bin directory: ~/.local/bin on Linux (XDG standard), ~/bin on macOS
if [[ -z "${CCSWITCH_BIN:-}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    BIN_DIR="$HOME/bin"
  else
    BIN_DIR="$HOME/.local/bin"
  fi
else
  BIN_DIR="$CCSWITCH_BIN"
fi

readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly SECRETS_FILE="$DATA_DIR/secrets.env"

# =============================================================================
# GLOBAL FLAGS (can be set via env vars)
# =============================================================================

VERBOSE="${CCSWITCH_VERBOSE:-0}"
DEBUG="${CCSWITCH_DEBUG:-0}"
QUIET="${CCSWITCH_QUIET:-0}"
YES_MODE="${CCSWITCH_YES:-0}"
NO_INPUT="${CCSWITCH_NO_INPUT:-0}"
NO_BANNER="${CCSWITCH_NO_BANNER:-0}"
OUTPUT_FORMAT="${CCSWITCH_OUTPUT_FORMAT:-human}"  # human, json, plain
DEFAULT_PROVIDER="${CCSWITCH_DEFAULT_PROVIDER:-}"

# =============================================================================
# TTY & COLOR DETECTION
# =============================================================================

is_tty() { [[ -t 1 ]]; }
is_stdin_tty() { [[ -t 0 ]]; }
is_interactive() { is_tty && is_stdin_tty && [[ "$NO_INPUT" != "1" ]]; }

setup_colors() {
  if is_tty && [[ -z "${NO_COLOR:-}" ]] && [[ "$OUTPUT_FORMAT" == "human" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    MAGENTA=$'\033[0;35m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
  else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
  fi
}

setup_symbols() {
  if [[ "${TERM:-}" == "dumb" ]] || [[ -n "${NO_COLOR:-}" ]]; then
    SYM_OK="[OK]" SYM_ERR="[X]" SYM_WARN="[!]" SYM_INFO=">" SYM_ARROW="->"
    SYM_CHECK="[x]" SYM_UNCHECK="[ ]"
    SYM_SPINNER=("-" "\\" "|" "/")
    BOX_TL="+" BOX_TR="+" BOX_BL="+" BOX_BR="+" BOX_H="-" BOX_V="|"
  else
    SYM_OK="✓" SYM_ERR="✗" SYM_WARN="⚠" SYM_INFO="→" SYM_ARROW="→"
    SYM_CHECK="✓" SYM_UNCHECK="○"
    SYM_SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    BOX_TL="╭" BOX_TR="╮" BOX_BL="╰" BOX_BR="╯" BOX_H="─" BOX_V="│"
  fi
}

setup_colors
setup_symbols

# =============================================================================
# LOGGING SYSTEM
# =============================================================================

debug()   { [[ "$DEBUG" == "1" ]] && echo -e "${DIM}[DEBUG] $*${NC}" >&2 || true; }
verbose() { [[ "$VERBOSE" == "1" || "$DEBUG" == "1" ]] && echo -e "${DIM}$*${NC}" >&2 || true; }
log()     { [[ "$QUIET" != "1" ]] && echo -e "${BLUE}${SYM_INFO}${NC} $*" || true; }
success() { echo -e "${GREEN}${SYM_OK}${NC} $*"; }
warn()    { echo -e "${YELLOW}${SYM_WARN}${NC} $*" >&2; }
error()   { echo -e "${RED}${SYM_ERR}${NC} $*" >&2; }

# Error with context, cause, and solution
error_ctx() {
  local code="$1" msg="$2" context="$3" cause="$4" solution="$5"
  echo >&2
  echo -e "${RED}${BOLD}ERROR${NC} ${DIM}[$code]${NC} ${BOLD}$msg${NC}" >&2
  echo -e "  ${DIM}Context:${NC}  $context" >&2
  echo -e "  ${DIM}Cause:${NC}    $cause" >&2
  echo -e "  ${CYAN}Fix:${NC}      $solution" >&2
  echo >&2
}

# Suggest next steps
suggest_next() {
  [[ "$QUIET" == "1" || "$OUTPUT_FORMAT" != "human" ]] && return
  echo -e "\n${BOLD}Next:${NC}"
  for s in "$@"; do echo -e "  ${CYAN}${SYM_ARROW}${NC} $s"; done
}

# =============================================================================
# UI COMPONENTS
# =============================================================================

draw_box() {
  local title="$1" width="${2:-52}"
  local inner=$((width - 2))
  if [[ ${#title} -gt $((inner - 4)) && inner -gt 10 ]]; then
    title="${title:0:$((inner - 7))}..."
  fi
  local pad=$(( (inner - ${#title}) / 2 ))

  # Use printf repeat instead of tr (tr fails with multi-byte UTF-8 on some Linux)
  local hline; printf -v hline "%${inner}s" ""; hline="${hline// /$BOX_H}"
  printf "%s%s%s\n" "$BOX_TL" "$hline" "$BOX_TR"
  printf "%s%${pad}s${BOLD}%s${NC}%$((inner - pad - ${#title}))s%s\n" "$BOX_V" "" "$title" "" "$BOX_V"
  printf "%s%s%s\n" "$BOX_BL" "$hline" "$BOX_BR"
}

draw_separator() {
  local width="${1:-52}"
  local hline; printf -v hline "%${width}s" ""; hline="${hline// /$BOX_H}"
  printf "${DIM}%s${NC}\n" "$hline"
}

# Spinner for long operations
SPINNER_PID=""
spinner_start() {
  local msg="${1:-Working...}"
  ! is_tty && { log "$msg"; return; }
  (
    local i=0
    while true; do
      printf "\r${BLUE}${SYM_SPINNER[$i]}${NC} %s " "$msg"
      i=$(( (i + 1) % ${#SYM_SPINNER[@]} ))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
  disown "$SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
  local status="${1:-0}" msg="${2:-Done}"
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[K"
  fi
  [[ "$status" -eq 0 ]] && success "$msg" || error "$msg"
}

# =============================================================================
# INPUT & PROMPTS
# =============================================================================

prompt() {
  local msg="$1" default="${2:-}" var="${3:-REPLY}"
  local prompt_text="$msg"; [[ -n "$default" ]] && prompt_text="$msg [$default]"
  read -r -p "$prompt_text: " "$var" || true
  if [[ -z "${!var}" && -n "$default" ]]; then
    printf -v "$var" "%s" "$default"
  fi
}

prompt_secret() {
  local msg="$1" var="${2:-REPLY}"
  read -rs -p "$msg: " "$var"; echo
}

confirm() {
  local msg="$1" default="${2:-n}"
  [[ "$YES_MODE" == "1" ]] && return 0
  local hint; [[ "$default" =~ ^[Yy] ]] && hint="[Y/n]" || hint="[y/N]"
  local resp; read -r -p "$msg $hint: " resp || true; resp="${resp:-$default}"
  [[ "$resp" =~ ^[Yy] ]] && return 0 || return 1
}

confirm_danger() {
  local action="$1" phrase="${2:-yes}"
  [[ "$YES_MODE" == "1" ]] && { warn "Auto-confirming: $action"; return 0; }
  echo; draw_box "DANGER" 40; echo
  echo -e "${RED}${BOLD}$action${NC}"; echo
  echo -e "Type ${YELLOW}${BOLD}$phrase${NC} to confirm:"
  local resp; read -r resp
  [[ "$resp" == "$phrase" ]]
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_name() {
  local name="$1" field="${2:-name}"
  if [[ ! "$name" =~ ^[a-z0-9_-]+$ ]]; then
    error_ctx "E001" "Invalid $field" "Validating: $name" \
      "Must be lowercase letters, digits, - or _" \
      "Use a valid name like 'my-provider'"
    return 1
  fi
}

validate_url() {
  local url="$1"
  if [[ ! "$url" =~ ^https?:// ]]; then
    error_ctx "E002" "Invalid URL" "Validating: $url" \
      "URL must start with http:// or https://" \
      "Provide a valid URL"
    return 1
  fi
}

validate_api_key() {
  local key="$1" provider="${2:-}"
  if [[ -z "$key" ]]; then
    error_ctx "E003" "API key is empty" "Configuring $provider" \
      "No API key provided" \
      "Enter your API key from the provider's dashboard"
    return 1
  fi
  if [[ ${#key} -lt 8 ]]; then
    error_ctx "E004" "API key too short" "Validating key for $provider" \
      "Key has ${#key} chars, minimum is 8" \
      "Check that you copied the full key"
    return 1
  fi
}

# =============================================================================
# SECRETS MANAGEMENT
# =============================================================================

load_secrets() {
  [[ ! -f "$SECRETS_FILE" ]] && return 0
  # Security checks
  if [[ -L "$SECRETS_FILE" ]]; then
    error "Secrets file is a symlink - refusing for security"; return 1
  fi
  local perms
  perms=$(stat -c "%a" "$SECRETS_FILE" 2>/dev/null || stat -f "%Lp" "$SECRETS_FILE" 2>/dev/null || echo "000")
  if [[ "$perms" != "600" ]]; then
    warn "Fixing secrets file permissions"; chmod 600 "$SECRETS_FILE"
  fi
  # Validate file format before sourcing
  local line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((++line_num))
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    # Validate format: VAR_NAME=value (VAR_NAME must start with letter or underscore, contain only uppercase letters, numbers, and underscores)
    if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
      error "Invalid line in secrets file at line $line_num: malformed variable assignment"
      error "Expected format: VAR_NAME=value (uppercase letters, numbers, underscores only)"
      return 1
    fi
  done < "$SECRETS_FILE"
  source "$SECRETS_FILE"
}

save_secret() {
  local key="$1" value="$2"
  mkdir -p "$(dirname "$SECRETS_FILE")"
  local tmp; tmp=$(mktemp "${SECRETS_FILE}.XXXXXX")
  [[ -f "$SECRETS_FILE" ]] && grep -v "^${key}=" "$SECRETS_FILE" > "$tmp" 2>/dev/null || true
  printf '%s=%q\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
}

mask_key() {
  local key="${1:-}"
  [[ -z "$key" ]] && { echo ""; return; }
  [[ ${#key} -le 8 ]] && { echo "****"; return; }
  echo "${key:0:4}****${key: -4}"
}

delete_secret() {
  local key="$1"
  [[ ! -f "$SECRETS_FILE" ]] && return 0
  local tmp; tmp=$(mktemp "${SECRETS_FILE}.XXXXXX")
  grep -v "^${key}=" "$SECRETS_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
}

cmd_keys() {
  local action="${1:-list}"
  local target="${2:-}"

  load_secrets

  case "$action" in
    list)
      echo
      echo -e "${BOLD}API Keys${NC}"
      draw_separator 50
      local found=0
      local all_providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
      for p in "${all_providers[@]}"; do
        local def; def=$(get_provider_def "$p")
        [[ -z "$def" ]] && continue
        IFS='|' read -r keyvar _ _ _ desc <<< "$def"
        [[ -z "$keyvar" || "$keyvar" == @* ]] && continue
        local val="${!keyvar:-}"
        if [[ -n "$val" ]]; then
          printf "  ${GREEN}%-12s${NC} %-20s %s\n" "$p" "$desc" "$(mask_key "$val")"
          ((++found)) || true
        else
          printf "  ${DIM}%-12s${NC} %-20s %s\n" "$p" "$desc" "${DIM}not set${NC}"
        fi
      done
      # OpenRouter
      if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        printf "  ${GREEN}%-12s${NC} %-20s %s\n" "openrouter" "OpenRouter" "$(mask_key "$OPENROUTER_API_KEY")"
        ((++found)) || true
      else
        printf "  ${DIM}%-12s${NC} %-20s %s\n" "openrouter" "OpenRouter" "${DIM}not set${NC}"
      fi
      # Custom base URLs
      if [[ -f "$SECRETS_FILE" ]]; then
        while IFS='=' read -r k _; do
          if [[ "$k" == CCSWITCH_*_BASE_URL ]]; then
            local cname="${k#CCSWITCH_}"
            cname="${cname%_BASE_URL}"
            cname=$(echo "$cname" | tr '[:upper:]' '[:lower:]')
            local ckey_var="${cname^^}_API_KEY"
            local cval="${!ckey_var:-}"
            printf "  ${GREEN}%-12s${NC} %-20s %s\n" "$cname" "Custom" "$(mask_key "$cval")"
            ((++found)) || true
          fi
        done < "$SECRETS_FILE"
      fi
      echo
      echo -e "${DIM}$found key(s) configured${NC}"
      echo
      echo -e "  ${DIM}Manage: ccswitch keys set <provider>${NC}"
      echo -e "  ${DIM}Delete: ccswitch keys delete <provider>${NC}"
      ;;

    set)
      if [[ -z "$target" ]]; then
        error "Usage: ccswitch keys set <provider>"
        return 1
      fi
      # Delegate to config
      cmd_config "$target"
      ;;

    delete|remove|rm)
      if [[ -z "$target" ]]; then
        error "Usage: ccswitch keys delete <provider>"
        return 1
      fi
      local def; def=$(get_provider_def "$target")
      local keyvar=""
      if [[ -n "$def" ]]; then
        IFS='|' read -r keyvar _ _ _ _ <<< "$def"
      elif [[ "$target" == "openrouter" ]]; then
        keyvar="OPENROUTER_API_KEY"
      fi
      if [[ -z "$keyvar" || "$keyvar" == @* ]]; then
        error "Provider '$target' does not use an API key"
        return 1
      fi
      if [[ -z "${!keyvar:-}" ]]; then
        warn "No API key set for '$target'"
        return 0
      fi
      confirm "Delete API key for $target?" || { log "Cancelled"; return 0; }
      delete_secret "$keyvar"
      # Also delete custom base URL if exists
      local base_url_key="CCSWITCH_${keyvar%_API_KEY}_BASE_URL"
      delete_secret "$base_url_key" 2>/dev/null || true
      success "API key for '$target' deleted"
      suggest_next "Reconfigure: ${GREEN}ccswitch config $target${NC}"
      ;;

    *)
      error "Unknown action: $action"
      echo -e "Usage: ccswitch keys [list|set|delete] [provider]"
      ;;
  esac
}

# =============================================================================
# MIGRATION FROM CLOTHER
# =============================================================================

migrate_from_clother() {
  local old_data="${XDG_DATA_HOME}/clother"
  local old_config="${XDG_CONFIG_HOME}/clother"
  local old_cache="${XDG_CACHE_HOME}/clother"

  # Check if old clother data exists and new data doesn't
  if [[ -d "$old_data" ]] && [[ ! -f "$SECRETS_FILE" ]]; then
    log "Detected existing Clother installation, migrating..."

    # Migrate data directory
    mkdir -p "$DATA_DIR"
    if [[ -f "$old_data/secrets.env" ]]; then
      # Copy and rename CLOTHER_* keys to CCSWITCH_*
      sed 's/^CLOTHER_/CCSWITCH_/' "$old_data/secrets.env" > "$SECRETS_FILE"
      chmod 600 "$SECRETS_FILE"
      success "Migrated secrets from Clother"
    fi
    if [[ -f "$old_data/banner" ]]; then
      cp "$old_data/banner" "$DATA_DIR/banner" 2>/dev/null || true
    fi

    # Migrate config directory
    if [[ -d "$old_config" ]]; then
      mkdir -p "$CONFIG_DIR"
      cp -r "$old_config"/* "$CONFIG_DIR"/ 2>/dev/null || true
      success "Migrated config from Clother"
    fi

    log "Migration complete. Old Clother files preserved at:"
    log "  $old_data"
    log "  $old_config"
    log "Run 'ccswitch uninstall' on old installation separately if desired."
  fi
}

# =============================================================================
# SIGNAL HANDLERS & CLEANUP
# =============================================================================

cleanup() {
  local exit_code="${1:-$?}"
  # Kill spinner if still running
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[K" 2>/dev/null || true
  fi
  tput cnorm 2>/dev/null || true  # Show cursor
  exit "$exit_code"
}

trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

# =============================================================================
# PROVIDER DEFINITIONS
# =============================================================================

get_provider_def() {
  # Format: keyvar|baseurl|model|model_opts|description
  case "$1" in
    native)     echo "|||Native Anthropic" ;;
    zai)        echo "ZAI_API_KEY|https://api.z.ai/api/anthropic|glm-5|haiku=glm-5,sonnet=glm-5,opus=glm-5|Z.AI International" ;;
    zai-cn)     echo "ZAI_CN_API_KEY|https://open.bigmodel.cn/api/anthropic|glm-5|haiku=glm-5,sonnet=glm-5,opus=glm-5|Z.AI China" ;;
    minimax)    echo "MINIMAX_API_KEY|https://api.minimax.io/anthropic|MiniMax-M2.5||MiniMax International" ;;
    minimax-cn) echo "MINIMAX_CN_API_KEY|https://api.minimaxi.com/anthropic|MiniMax-M2.5||MiniMax China" ;;
    kimi)       echo "KIMI_API_KEY|https://api.kimi.com/coding/|kimi-k2.5|small=kimi-k2.5|Kimi K2" ;;
    moonshot)   echo "MOONSHOT_API_KEY|https://api.moonshot.ai/anthropic|kimi-k2.5||Moonshot AI" ;;
    ve)         echo "ARK_API_KEY|https://ark.cn-beijing.volces.com/api/coding|doubao-seed-code-preview-latest||VolcEngine" ;;
    deepseek)   echo "DEEPSEEK_API_KEY|https://api.deepseek.com/anthropic|deepseek-chat|small=deepseek-chat|DeepSeek" ;;
    mimo)       echo "MIMO_API_KEY|https://api.xiaomimimo.com/anthropic|mimo-v2-flash|haiku=mimo-v2-flash,sonnet=mimo-v2-flash,opus=mimo-v2-flash|Xiaomi MiMo" ;;
    # Local providers (no API key needed)
    ollama)     echo "@ollama|http://localhost:11434|||Ollama (Local)" ;;
    lmstudio)   echo "@lmstudio|http://localhost:1234|||LM Studio (Local)" ;;
    llamacpp)   echo "@|http://localhost:8000|||llama.cpp (Local)" ;;
    *)          echo "" ;;
  esac
}

is_provider_configured() {
  local provider="$1"
  local def; def=$(get_provider_def "$provider")
  [[ -z "$def" ]] && return 1
  IFS='|' read -r keyvar _ _ _ _ <<< "$def"
  [[ -z "$keyvar" ]] && return 0  # native
  [[ "$keyvar" == @* ]] && return 0  # local providers (ollama, lmstudio, llamacpp)
  [[ -n "${!keyvar:-}" ]]
}

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
  keys         Manage API keys (list/set/delete)
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
  list                 List all configured profiles
  info <provider>      Show details for a provider
  test [provider]      Test provider connectivity
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
    *)
      show_full_help
      ;;
  esac
}

# Command suggestion (prefix/substring match)
suggest_command() {
  local input="$1"
  local -a commands=(config list info test status uninstall help)
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

cmd_list() {
  load_secrets

  local -a profiles=()
  for f in "$BIN_DIR"/ccswitch-*; do
    [[ -x "$f" ]] || continue
    local name; name=$(basename "$f" | sed 's/^ccswitch-//')
    profiles+=("$name")
  done

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo -n '{"profiles":['
    local first=true
    for p in "${profiles[@]}"; do
      $first || echo -n ","
      first=false
      # Escape quotes for JSON safety
      local safe_p="${p//\"/\\\"}"
      echo -n "{\"name\":\"$safe_p\",\"command\":\"ccswitch-$safe_p\"}"
    done
    echo ']}'
    return
  fi

  if [[ ${#profiles[@]} -eq 0 ]]; then
    warn "No profiles configured"
    suggest_next "Configure one: ${GREEN}ccswitch config${NC}"
    return
  fi

  echo -e "${BOLD}Available Profiles (${#profiles[@]}):${NC}"
  echo
  for p in "${profiles[@]}"; do
    local status="${DIM}${SYM_UNCHECK}${NC}"
    # Check if configured
    local def; def=$(get_provider_def "$p")
    if [[ -n "$def" ]]; then
      is_provider_configured "$p" && status="${GREEN}${SYM_CHECK}${NC}"
    elif [[ "$p" == or-* ]]; then
      [[ -n "${OPENROUTER_API_KEY:-}" ]] && status="${GREEN}${SYM_CHECK}${NC}"
    fi
    echo -e "  $status ${YELLOW}$p${NC}"
  done
  echo
  echo -e "${DIM}Run: ${NC}${GREEN}ccswitch-<name>${NC}"
}

cmd_info() {
  local provider="${1:-}"
  [[ -z "$provider" ]] && { error "Usage: ccswitch info <provider>"; return 1; }

  load_secrets

  local def; def=$(get_provider_def "$provider")

  echo
  echo -e "${BOLD}Provider: ${YELLOW}$provider${NC}"
  draw_separator 40

  if [[ -n "$def" ]]; then
    IFS='|' read -r keyvar baseurl model model_opts description <<< "$def"
    echo -e "Description: $description"
    echo -e "Base URL:    ${baseurl:-default}"
    echo -e "Model:       ${model:-default}"
    if [[ -n "$keyvar" ]]; then
      local status; [[ -n "${!keyvar:-}" ]] && status="${GREEN}configured${NC}" || status="${RED}not set${NC}"
      echo -e "API Key:     $status"
    fi
  elif [[ "$provider" == or-* ]]; then
    local short="${provider#or-}"
    local keyvar="OPENROUTER_MODEL_$(echo "$short" | tr '[:lower:]-' '[:upper:]_')"
    echo -e "Type:        OpenRouter"
    echo -e "Model:       ${!keyvar:-unknown}"
    echo -e "Endpoint:    https://openrouter.ai/api"
  else
    echo -e "Type:        Custom/Unknown"
  fi
}

cmd_test() {
  local provider="${1:-}"

  load_secrets

  echo
  echo -e "${BOLD}Testing Providers${NC}"
  draw_separator 40

  local providers_to_test=()
  if [[ -n "$provider" ]]; then
    providers_to_test=("$provider")
  else
    # Get all configured providers
    for f in "$BIN_DIR"/ccswitch-*; do
      [[ -x "$f" ]] || continue
      local name; name=$(basename "$f" | sed 's/^ccswitch-//')
      [[ "$name" != "native" ]] && providers_to_test+=("$name")
    done
  fi

  local ok=0 fail=0 skip=0
  for p in "${providers_to_test[@]}"; do
    printf "  Testing %-15s " "$p"

    local def; def=$(get_provider_def "$p")
    local test_url=""

    if [[ -n "$def" ]]; then
      IFS='|' read -r keyvar baseurl _ _ _ <<< "$def"
      # Check API key for non-local, non-native providers
      if [[ -n "$keyvar" && "$keyvar" != @* && -z "${!keyvar:-}" ]]; then
        echo -e "${YELLOW}not configured${NC}"
        ((++fail)) || true
        continue
      fi
      test_url="${baseurl:-https://api.anthropic.com}"
    elif [[ "$p" == or-* ]]; then
      if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        echo -e "${YELLOW}not configured${NC}"
        ((++fail)) || true
        continue
      fi
      test_url="https://openrouter.ai/api"
    fi

    if [[ -z "$test_url" ]]; then
      echo -e "${DIM}skipped${NC}"
      ((++skip)) || true
      continue
    fi

    # Test endpoint: try HTTP first, fall back to TLS-connect check
    # Many API servers reject bare GET but are fully operational
    local http_code tls_time
    http_code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$test_url" 2>/dev/null) || http_code="000"
    if [[ "$http_code" != "000" ]]; then
      echo -e "${GREEN}${SYM_OK} reachable${NC} ${DIM}(HTTP $http_code)${NC}"
      ((++ok)) || true
    else
      # HTTP failed (stream error, etc.) -- check if TLS handshake works
      tls_time=$(curl -s --max-time 5 -o /dev/null -w "%{time_appconnect}" "$test_url" 2>/dev/null) || tls_time="0"
      if [[ "$tls_time" != "0" && "$tls_time" != "0.000000" ]]; then
        echo -e "${GREEN}${SYM_OK} connected${NC} ${DIM}(TLS ok)${NC}"
        ((++ok)) || true
      else
        echo -e "${RED}${SYM_ERR} unreachable${NC}"
        ((++fail)) || true
      fi
    fi
  done

  echo
  echo -e "Results: ${GREEN}$ok reachable${NC}, ${RED}$fail failed${NC}$([[ $skip -gt 0 ]] && echo ", ${DIM}$skip skipped${NC}")"
}

cmd_status() {
  load_secrets

  echo
  draw_box "CCSWITCH STATUS" 50
  echo
  echo -e "  Version:     ${BOLD}$VERSION${NC}"
  echo -e "  Config:      $CONFIG_DIR"
  echo -e "  Data:        $DATA_DIR"
  echo -e "  Bin:         $BIN_DIR"
  echo

  local count=0
  for f in "$BIN_DIR"/ccswitch-*; do [[ -x "$f" ]] && ((++count)) || true; done
  echo -e "  Profiles:    ${BOLD}$count${NC} installed"

  if [[ -n "$DEFAULT_PROVIDER" ]]; then
    echo -e "  Default:     ${YELLOW}$DEFAULT_PROVIDER${NC}"
  fi
}

cmd_uninstall() {
  echo
  echo -e "${BOLD}Uninstall CCSwitch${NC}"
  echo
  echo "This will remove:"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $CONFIG_DIR"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $DATA_DIR"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $BIN_DIR/ccswitch*"
  echo

  confirm_danger "Remove all CCSwitch files" "delete ccswitch" || return 1

  spinner_start "Removing files..."
  rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$BIN_DIR"/ccswitch-* "$BIN_DIR/ccswitch" 2>/dev/null || true
  spinner_stop 0 "CCSwitch uninstalled"
}

# =============================================================================
# LAUNCHER GENERATORS
# =============================================================================

generate_launcher() {
  local name="$1" keyvar="$2" baseurl="$3" model="$4" model_opts="$5"

  mkdir -p "$BIN_DIR"

  cat > "$BIN_DIR/ccswitch-$name" << LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
[[ "\${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo "    + $name" && echo
SECRETS="\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch/secrets.env"
if [[ -f "\$SECRETS" ]]; then
  [[ -L "\$SECRETS" ]] && { echo "Error: secrets file is a symlink - refusing for security" >&2; exit 1; }
  source "\$SECRETS"
fi
LAUNCHER

  if [[ -n "$keyvar" ]]; then
    cat >> "$BIN_DIR/ccswitch-$name" << LAUNCHER
[[ -z "\${$keyvar:-}" ]] && { echo "Error: $keyvar not set. Run 'ccswitch config'" >&2; exit 1; }
export ANTHROPIC_AUTH_TOKEN="\$$keyvar"
LAUNCHER
  fi

  [[ -n "$baseurl" ]] && echo "export ANTHROPIC_BASE_URL=\"$baseurl\"" >> "$BIN_DIR/ccswitch-$name"
  [[ -n "$model" ]] && echo "export ANTHROPIC_MODEL=\"$model\"" >> "$BIN_DIR/ccswitch-$name"

  # Parse model_opts
  if [[ -n "$model_opts" ]]; then
    IFS=',' read -ra opts <<< "$model_opts"
    for opt in "${opts[@]}"; do
      IFS='=' read -r key val <<< "$opt"
      case "$key" in
        haiku)  echo "export ANTHROPIC_DEFAULT_HAIKU_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        sonnet) echo "export ANTHROPIC_DEFAULT_SONNET_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        opus)   echo "export ANTHROPIC_DEFAULT_OPUS_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        small)  echo "export ANTHROPIC_SMALL_FAST_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
      esac
    done
  fi

  echo 'exec claude "$@"' >> "$BIN_DIR/ccswitch-$name"
  chmod +x "$BIN_DIR/ccswitch-$name"
}

generate_or_launcher() {
  local name="$1" model="$2"

  mkdir -p "$BIN_DIR"

  # OpenRouter now supports native Anthropic API format
  # No proxy needed - direct connection to https://openrouter.ai/api
  cat > "$BIN_DIR/ccswitch-or-$name" << LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
[[ "\${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo "    + OpenRouter: $name" && echo
SECRETS="\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch/secrets.env"
if [[ -f "\$SECRETS" ]]; then
  [[ -L "\$SECRETS" ]] && { echo "Error: secrets file is a symlink - refusing for security" >&2; exit 1; }
  source "\$SECRETS"
fi
[[ -z "\${OPENROUTER_API_KEY:-}" ]] && { echo "Error: OPENROUTER_API_KEY not set. Run 'ccswitch config openrouter'" >&2; exit 1; }

# OpenRouter native Anthropic API support
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="\$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY=""  # Must be explicitly empty

# Override all model tiers to use the selected model
export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
export ANTHROPIC_SMALL_FAST_MODEL="$model"

exec claude "\$@"
LAUNCHER
  chmod +x "$BIN_DIR/ccswitch-or-$name"
}

generate_local_launcher() {
  local name="$1" baseurl="$2" auth_token="$3" model="$4" model_opts="$5"

  mkdir -p "$BIN_DIR"

  cat > "$BIN_DIR/ccswitch-$name" << LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
[[ "\${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo "    + $name (local)" && echo
export ANTHROPIC_BASE_URL="$baseurl"
LAUNCHER

  if [[ -n "$auth_token" ]]; then
    cat >> "$BIN_DIR/ccswitch-$name" << LAUNCHER
export ANTHROPIC_AUTH_TOKEN="$auth_token"
export ANTHROPIC_API_KEY=""
LAUNCHER
  fi

  [[ -n "$model" ]] && echo "export ANTHROPIC_MODEL=\"$model\"" >> "$BIN_DIR/ccswitch-$name"

  # Parse model_opts
  if [[ -n "$model_opts" ]]; then
    IFS=',' read -ra opts <<< "$model_opts"
    for opt in "${opts[@]}"; do
      IFS='=' read -r key val <<< "$opt"
      case "$key" in
        haiku)  echo "export ANTHROPIC_DEFAULT_HAIKU_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        sonnet) echo "export ANTHROPIC_DEFAULT_SONNET_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        opus)   echo "export ANTHROPIC_DEFAULT_OPUS_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
        small)  echo "export ANTHROPIC_SMALL_FAST_MODEL=\"$val\"" >> "$BIN_DIR/ccswitch-$name" ;;
      esac
    done
  fi

  echo 'exec claude "$@"' >> "$BIN_DIR/ccswitch-$name"
  chmod +x "$BIN_DIR/ccswitch-$name"
}


# =============================================================================
# INSTALLATION
# =============================================================================

do_install() {
  [[ "$NO_BANNER" != "1" ]] && echo -e "$BANNER"
  echo -e "${BOLD}CCSwitch $VERSION${NC}"
  echo

  migrate_from_clother

  # Check prerequisites BEFORE any destructive operations
  log "Checking for 'claude' command..."
  if ! command -v claude &>/dev/null; then
    error_ctx "E010" "Claude CLI not found" "Checking prerequisites" \
      "The 'claude' command is not installed" \
      "Install: ${CYAN}curl -fsSL https://claude.ai/install.sh | bash${NC}"
    exit 1
  fi
  success "'claude' found"

  # Back up secrets to temp file before cleaning (survives interruption)
  local secrets_tmp=""
  if [[ -f "$SECRETS_FILE" ]]; then
    secrets_tmp=$(mktemp "${TMPDIR:-/tmp}/ccswitch-secrets.XXXXXX")
    cp -p "$SECRETS_FILE" "$secrets_tmp"
  fi
  rm -f "$BIN_DIR/ccswitch" "$BIN_DIR"/ccswitch-* 2>/dev/null || true
  rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" 2>/dev/null || true

  # Create directories (XDG compliant)
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$BIN_DIR"

  # Restore secrets from temp backup
  if [[ -n "$secrets_tmp" && -f "$secrets_tmp" ]]; then
    mv "$secrets_tmp" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
  fi

  # Save banner
  echo "$BANNER" > "$DATA_DIR/banner"

  # Generate main command
  generate_main_command

  # Generate native launcher
  cat > "$BIN_DIR/ccswitch-native" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo "    + native" && echo
exec claude "$@"
EOF
  chmod +x "$BIN_DIR/ccswitch-native"

  # Generate standard launchers
  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  for p in "${providers[@]}"; do
    local def; def=$(get_provider_def "$p")
    IFS='|' read -r keyvar baseurl model model_opts _ <<< "$def"
    generate_launcher "$p" "$keyvar" "$baseurl" "$model" "$model_opts"
  done

  # Generate local launchers (Ollama, LM Studio, llama.cpp)
  generate_local_launcher "ollama" "http://localhost:11434" "ollama" "" ""
  generate_local_launcher "lmstudio" "http://localhost:1234" "lmstudio" "" ""
  generate_local_launcher "llamacpp" "http://localhost:8000" "" "" ""

  # Verify
  if ! "$BIN_DIR/ccswitch" --version &>/dev/null; then
    error "Installation verification failed"
    exit 1
  fi

  success "Installed CCSwitch v$VERSION"

  # PATH warning
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo
    warn "Add '$BIN_DIR' to PATH:"
    local shell_rc="$HOME/.bashrc"
    [[ "${SHELL##*/}" == "zsh" ]] && shell_rc="$HOME/.zshrc"
    echo -e "  ${YELLOW}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $shell_rc${NC}"
    echo -e "  ${YELLOW}source $shell_rc${NC}"
  fi

  suggest_next \
    "Configure a provider: ${GREEN}ccswitch config${NC}" \
    "Use native Claude: ${GREEN}ccswitch-native${NC}" \
    "View help: ${GREEN}ccswitch --help${NC}"
}

generate_main_command() {
  cat > "$BIN_DIR/ccswitch" << 'MAINEOF'
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

# Re-exec with the full script for complex commands
SCRIPT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch"
if [[ -f "$SCRIPT_DIR/ccswitch-full.sh" ]]; then
  exec bash "$SCRIPT_DIR/ccswitch-full.sh" "$@"
fi

# Fallback minimal implementation
echo "CCSwitch - Run installer to complete setup"
MAINEOF
  chmod +x "$BIN_DIR/ccswitch"

  # Copy this script as the full implementation
  if [[ ! -f "${BASH_SOURCE[0]:-}" ]]; then
    # Piped execution - download from GitHub
    curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh > "$DATA_DIR/ccswitch-full.sh"
  else
    cp "${BASH_SOURCE[0]}" "$DATA_DIR/ccswitch-full.sh"
  fi
  chmod +x "$DATA_DIR/ccswitch-full.sh"
}

# =============================================================================
# BANNER
# =============================================================================

read -r -d '' BANNER << 'EOF' || true
   ____ ____ ____          _ _       _
  / ___/ ___/ ___|_      _(_) |_ ___| |__
 | |  | |   \___ \ \ /\ / / | __/ __| '_ \
 | |__| |___ ___) \ V  V /| | || (__| | | |
  \____\____|____/ \_/\_/ |_|\__\___|_| |_|
EOF

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)    [[ -n "${2:-}" && ! "$2" =~ ^- ]] && { show_command_help "$2"; exit 0; }; show_full_help; exit 0 ;;
      -V|--version) show_version; exit 0 ;;
      -v|--verbose) VERBOSE=1 ;;
      -d|--debug)   DEBUG=1; VERBOSE=1 ;;
      -q|--quiet)   QUIET=1 ;;
      -y|--yes)     YES_MODE=1 ;;
      --bin-dir)    [[ -n "${2:-}" ]] || { error "--bin-dir requires a path argument"; exit 1; }; BIN_DIR="$2"; shift ;;
      --no-input)   NO_INPUT=1 ;;
      --no-color)   NO_COLOR=1; setup_colors ;;
      --no-banner)  NO_BANNER=1 ;;
      --json)       OUTPUT_FORMAT=json ;;
      --plain)      OUTPUT_FORMAT=plain; NO_COLOR=1; setup_colors ;;
      --)           shift; REMAINING_ARGS+=("$@"); break ;;
      -*)           error "Unknown option: $1"; echo "Use --help for usage"; exit 1 ;;
      *)            REMAINING_ARGS+=("$1") ;;
    esac
    shift
  done
}

# =============================================================================
# AUTO-UPDATE
# =============================================================================

check_update() {
  # Skip if explicitly disabled or non-interactive
  [[ "${CCSWITCH_NO_UPDATE:-}" == "1" ]] && return 0
  [[ ! -t 1 ]] && return 0

  local stamp_file="$CACHE_DIR/last_update_check"
  mkdir -p "$CACHE_DIR"

  # Only check once per UPDATE_CHECK_INTERVAL
  if [[ -f "$stamp_file" ]]; then
    local last_check
    last_check=$(cat "$stamp_file" 2>/dev/null || echo 0)
    local now; now=$(date +%s)
    if (( now - last_check < UPDATE_CHECK_INTERVAL )); then
      return 0
    fi
  fi

  # Record check time
  date +%s > "$stamp_file"

  # Fetch remote version (timeout 3s, background-safe)
  local remote_version
  remote_version=$(curl -fsSL --max-time 3 "$CCSWITCH_RAW" 2>/dev/null | grep -m1 '^readonly VERSION=' | sed 's/.*="\(.*\)"/\1/') || return 0

  [[ -z "$remote_version" ]] && return 0
  [[ "$remote_version" == "$VERSION" ]] && return 0

  echo
  log "New version available: ${GREEN}v$remote_version${NC} (current: v$VERSION)"
  local do_update="n"
  if [[ "${YES_MODE:-0}" == "1" ]]; then
    do_update="y"
  else
    confirm "Update now?" && do_update="y"
  fi

  if [[ "$do_update" == "y" ]]; then
    do_self_update
  else
    log "Skip update. Run ${CYAN}ccswitch update${NC} to update manually."
  fi
}

do_self_update() {
  log "Downloading v$VERSION -> latest..."
  local tmp; tmp=$(mktemp "${TMPDIR:-/tmp}/ccswitch-update.XXXXXX")
  if ! curl -fsSL --max-time 15 "$CCSWITCH_RAW" -o "$tmp" 2>/dev/null; then
    error "Download failed"
    rm -f "$tmp"
    return 1
  fi

  # Validate downloaded script
  if ! bash -n "$tmp" 2>/dev/null; then
    error "Downloaded script has syntax errors, aborting update"
    rm -f "$tmp"
    return 1
  fi

  local new_version
  new_version=$(grep -m1 '^readonly VERSION=' "$tmp" | sed 's/.*="\(.*\)"/\1/')
  if [[ -z "$new_version" ]]; then
    error "Could not determine version of downloaded script"
    rm -f "$tmp"
    return 1
  fi

  # Replace the full script
  cp "$tmp" "$DATA_DIR/ccswitch-full.sh"
  chmod +x "$DATA_DIR/ccswitch-full.sh"
  rm -f "$tmp"

  success "Updated to v$new_version"
  log "Restart ccswitch to use the new version."
}

cmd_update() {
  log "Checking for updates..."
  local remote_version
  remote_version=$(curl -fsSL --max-time 5 "$CCSWITCH_RAW" 2>/dev/null | grep -m1 '^readonly VERSION=' | sed 's/.*="\(.*\)"/\1/') || true

  if [[ -z "$remote_version" ]]; then
    error "Could not reach update server"
    return 1
  fi

  if [[ "$remote_version" == "$VERSION" ]]; then
    success "Already on latest version (v$VERSION)"
    return 0
  fi

  log "New version available: ${GREEN}v$remote_version${NC} (current: v$VERSION)"
  do_self_update
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  parse_args "$@"
  set -- ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}

  local cmd="${1:-}"
  shift || true

  # Auto-update check (silent, non-blocking)
  [[ "$cmd" != "update" && "$cmd" != "uninstall" ]] && check_update

  case "$cmd" in
    "")         show_brief_help ;;
    config)     cmd_config "$@" ;;
    list)       cmd_list "$@" ;;
    info)       cmd_info "$@" ;;
    test)       cmd_test "$@" ;;
    keys)       cmd_keys "$@" ;;
    status)     cmd_status "$@" ;;
    uninstall)  cmd_uninstall "$@" ;;
    update)     cmd_update ;;
    help)       [[ -n "${1:-}" ]] && show_command_help "$1" || show_full_help ;;
    install)    do_install ;;
    *)
      error "Unknown command: $cmd"
      local suggestion; suggestion=$(suggest_command "$cmd")
      [[ -n "$suggestion" ]] && echo -e "Did you mean: ${GREEN}ccswitch $suggestion${NC}?"
      exit 1
      ;;
  esac
}

# If sourced, don't run main
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]] || [[ ! -f "${BASH_SOURCE[0]:-}" ]]; then
  # Piped execution (curl | bash) or first run -> install
  if [[ ! -f "${BASH_SOURCE[0]:-}" ]] || [[ ! -f "$BIN_DIR/ccswitch" ]]; then
    do_install
  else
    main "$@"
  fi
fi
