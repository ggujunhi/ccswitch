#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Model Management
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains model management commands: list, update, apply, diff, pin, unpin.
#
# Requires: lib/core.sh (for REGISTRY_URL, CACHE_DIR, CONFIG_DIR, BIN_DIR, etc.)
#           lib/utils.sh (for logging, colors, prompts)
#           lib/validation.sh (for validation functions)
#           lib/secrets.sh (for secret management)
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

readonly CCSWITCH_COMMANDS_MODELS_LOADED=1

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
# MODEL REGISTRY
# =============================================================================

readonly PINS_FILE="$CONFIG_DIR/model-pins"
readonly REGISTRY_FILE="$CACHE_DIR/models.json"

fetch_model_registry() {
  local force="${1:-}"
  local stamp_file="$CACHE_DIR/last_model_check"
  mkdir -p "$CACHE_DIR"

  if [[ "$force" != "force" && -f "$stamp_file" ]]; then
    local last_check; last_check=$(cat "$stamp_file" 2>/dev/null || echo 0)
    local now; now=$(date +%s)
    if (( now - last_check < UPDATE_CHECK_INTERVAL )); then
      return 0
    fi
  fi

  date +%s > "$stamp_file"

  local tmp; tmp=$(mktemp "$CACHE_DIR/ccswitch-registry.XXXXXX")
  if curl -fsSL --max-time 5 "$REGISTRY_URL" -o "$tmp" 2>/dev/null; then
    if grep -q '"_version"' "$tmp"; then
      mv "$tmp" "$REGISTRY_FILE"
    else
      rm -f "$tmp"
    fi
  else
    rm -f "$tmp"
  fi
}

# Parse a field from the cached registry for a provider
# Usage: registry_get <provider> <field>  (field: model, opts, v)
registry_get() {
  local provider="$1" field="$2"
  [[ -f "$REGISTRY_FILE" ]] || return 1
  local entry
  entry=$(grep -o "\"${provider}\"[^}]*}" "$REGISTRY_FILE" 2>/dev/null) || return 1
  local val
  val=$(echo "$entry" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*:[[:space:]]*"//;s/"$//') || return 1
  # Validate extracted value against safe character whitelist
  if [[ -n "$val" && ! "$val" =~ ^[a-zA-Z0-9_./:+=-]+$ ]]; then
    warn "Registry value for $provider.$field contains unsafe characters, ignoring"
    return 1
  fi
  [[ -n "$val" ]] && echo "$val"
}

# Read a user-pinned model for a provider
get_pinned_model() {
  local provider="$1"
  [[ -f "$PINS_FILE" ]] || return 1
  local val
  local escaped_p; escaped_p=$(printf '%s' "$provider" | sed 's/[.[\*^$]/\\&/g')
  val=$(grep "^${escaped_p}=" "$PINS_FILE" 2>/dev/null | head -1 | cut -d= -f2-) || return 1
  [[ -n "$val" ]] && echo "$val"
}

# Resolve the effective model for a provider: pin > registry > hardcoded
resolve_model() {
  local provider="$1"
  local pinned; pinned=$(get_pinned_model "$provider" 2>/dev/null) || true
  if [[ -n "$pinned" ]]; then echo "$pinned"; return; fi
  local reg; reg=$(registry_get "$provider" "model" 2>/dev/null) || true
  if [[ -n "$reg" ]]; then echo "$reg"; return; fi
  # Fallback: extract hardcoded model from get_provider_def
  local def; def=$(get_provider_def "$provider")
  [[ -n "$def" ]] && IFS='|' read -r _ _ model _ _ <<< "$def" && echo "$model"
}

resolve_model_opts() {
  local provider="$1"
  local reg; reg=$(registry_get "$provider" "opts" 2>/dev/null) || true
  if [[ -n "$reg" ]]; then echo "$reg"; return; fi
  local def; def=$(get_provider_def "$provider")
  [[ -n "$def" ]] && IFS='|' read -r _ _ _ opts _ <<< "$def" && echo "$opts"
}

# Determine the source of the effective model
model_source() {
  local provider="$1"
  local pinned; pinned=$(get_pinned_model "$provider" 2>/dev/null) || true
  [[ -n "$pinned" ]] && echo "pinned" && return
  local reg; reg=$(registry_get "$provider" "model" 2>/dev/null) || true
  [[ -n "$reg" ]] && echo "registry" && return
  echo "hardcoded"
}

check_model_updates() {
  [[ "${CCSWITCH_NO_UPDATE:-}" == "1" ]] && return 0
  [[ ! -t 1 ]] && return 0
  fetch_model_registry

  [[ -f "$REGISTRY_FILE" ]] || return 0

  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  local updates=()
  for p in "${providers[@]}"; do
    local launcher="$BIN_DIR/ccswitch-$p"
    [[ -f "$launcher" ]] || continue
    local current; current=$(grep '^export ANTHROPIC_MODEL=' "$launcher" 2>/dev/null | sed 's/.*="//;s/"$//' ) || continue
    [[ -z "$current" ]] && continue
    local latest; latest=$(resolve_model "$p") || continue
    [[ -z "$latest" || "$current" == "$latest" ]] && continue
    updates+=("$p: $current -> $latest")
  done

  if [[ ${#updates[@]} -gt 0 ]]; then
    echo
    warn "Model updates available:"
    for u in "${updates[@]}"; do
      echo -e "  ${CYAN}$u${NC}"
    done
    echo -e "  Run ${GREEN}ccswitch models apply${NC} to update launchers"
    echo
  fi
}

# =============================================================================
# MODEL COMMANDS
# =============================================================================

cmd_models() {
  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    ""|list)  cmd_models_list ;;
    update)   cmd_models_update ;;
    apply)    cmd_models_apply ;;
    diff)     cmd_models_diff ;;
    pin)      cmd_models_pin "$@" ;;
    unpin)    cmd_models_unpin "$@" ;;
    *)        error "Unknown action: $action"; echo "Usage: ccswitch models [list|update|apply|diff|pin|unpin]" ;;
  esac
}

cmd_models_list() {
  fetch_model_registry

  local reg_date=""
  if [[ -f "$REGISTRY_FILE" ]]; then
    reg_date=$(grep -o '"_updated"[^,}]*' "$REGISTRY_FILE" 2>/dev/null | sed 's/.*"//;s/"$//' ) || true
  fi

  echo
  echo -e "${BOLD}Models${NC}${reg_date:+ ${DIM}(registry: $reg_date)${NC}}"
  draw_separator 60
  printf "  ${DIM}%-12s %-28s %s${NC}\n" "Provider" "Model" "Source"
  draw_separator 60

  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  for p in "${providers[@]}"; do
    local model; model=$(resolve_model "$p")
    local src; src=$(model_source "$p")
    local color="$NC"
    case "$src" in
      pinned)    color="$YELLOW" ;;
      registry)  color="$GREEN" ;;
      hardcoded) color="$DIM" ;;
    esac
    printf "  %-12s %-28s ${color}%s${NC}\n" "$p" "${model:-?}" "$src"
  done

  echo
  local stamp_file="$CACHE_DIR/last_model_check"
  if [[ -f "$stamp_file" ]]; then
    local last; last=$(cat "$stamp_file" 2>/dev/null || echo 0)
    local now; now=$(date +%s)
    local ago=$(( now - last ))
    if (( ago < 60 )); then
      echo -e "  ${DIM}Last checked: just now${NC}"
    elif (( ago < 3600 )); then
      echo -e "  ${DIM}Last checked: $(( ago / 60 ))m ago${NC}"
    else
      echo -e "  ${DIM}Last checked: $(( ago / 3600 ))h ago${NC}"
    fi
  fi
}

cmd_models_update() {
  log "Fetching latest model registry..."
  fetch_model_registry "force"
  if [[ -f "$REGISTRY_FILE" ]]; then
    local reg_date
    reg_date=$(grep -o '"_updated"[^,}]*' "$REGISTRY_FILE" 2>/dev/null | sed 's/.*"//;s/"$//' ) || true
    success "Registry updated${reg_date:+ ($reg_date)}"
    cmd_models_diff
    echo
    log "Run ${CYAN}ccswitch models apply${NC} to regenerate launchers with new models."
  else
    error "Failed to fetch registry"
  fi
}

cmd_models_apply() {
  fetch_model_registry

  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  local changed=0

  for p in "${providers[@]}"; do
    local def; def=$(get_provider_def "$p")
    [[ -z "$def" ]] && continue
    IFS='|' read -r keyvar baseurl _ _ _ <<< "$def"

    local resolved_model; resolved_model=$(resolve_model "$p")
    local resolved_opts; resolved_opts=$(resolve_model_opts "$p")
    [[ -z "$resolved_model" ]] && continue

    # Check current launcher model
    local launcher="$BIN_DIR/ccswitch-$p"
    if [[ -f "$launcher" ]]; then
      local current; current=$(grep '^export ANTHROPIC_MODEL=' "$launcher" 2>/dev/null | sed 's/.*="//;s/"$//' ) || true
      [[ "$current" == "$resolved_model" ]] && continue
      log "Updating $p: ${DIM}$current${NC} -> ${GREEN}$resolved_model${NC}"
    else
      log "Generating $p: ${GREEN}$resolved_model${NC}"
    fi

    generate_launcher "$p" "$keyvar" "$baseurl" "$resolved_model" "$resolved_opts"
    ((++changed)) || true
  done

  if [[ $changed -eq 0 ]]; then
    success "All launchers up to date"
  else
    success "Regenerated $changed launcher(s)"
  fi
}

cmd_models_diff() {
  fetch_model_registry

  echo
  printf "  ${DIM}%-12s %-20s %-20s %-20s${NC}\n" "Provider" "Hardcoded" "Registry" "Pinned"
  draw_separator 75

  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  for p in "${providers[@]}"; do
    local def; def=$(get_provider_def "$p")
    IFS='|' read -r _ _ hc_model _ _ <<< "$def"
    local reg_model; reg_model=$(registry_get "$p" "model" 2>/dev/null) || reg_model="-"
    local pin_model; pin_model=$(get_pinned_model "$p" 2>/dev/null) || pin_model="-"

    local mark=""
    if [[ "$reg_model" != "-" && "$reg_model" != "$hc_model" ]]; then
      mark=" ${CYAN}NEW${NC}"
    fi

    printf "  %-12s %-20s %-20s %-20s%b\n" "$p" "${hc_model:-?}" "$reg_model" "$pin_model" "$mark"
  done
  echo
}

cmd_models_pin() {
  local provider="${1:-}" model="${2:-}"
  if [[ -z "$provider" || -z "$model" ]]; then
    error "Usage: ccswitch models pin <provider> <model>"
    echo -e "Example: ${GREEN}ccswitch models pin zai glm-4.7${NC}"
    return 1
  fi
  # Validate provider exists
  local def; def=$(get_provider_def "$provider")
  if [[ -z "$def" ]]; then
    error "Unknown provider: $provider"
    return 1
  fi
  mkdir -p "$CONFIG_DIR"
  # Remove existing pin
  if [[ -f "$PINS_FILE" ]]; then
    local tmp; tmp=$(mktemp "${PINS_FILE}.XXXXXX")
    local escaped_p; escaped_p=$(printf '%s' "$provider" | sed 's/[.[\*^$]/\\&/g')
    grep -v "^${escaped_p}=" "$PINS_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$PINS_FILE"
  fi
  echo "${provider}=${model}" >> "$PINS_FILE"
  success "Pinned $provider to ${CYAN}$model${NC}"
  suggest_next "Apply to launcher: ${GREEN}ccswitch models apply${NC}"
}

cmd_models_unpin() {
  local provider="${1:-}"
  if [[ -z "$provider" ]]; then
    error "Usage: ccswitch models unpin <provider>"
    return 1
  fi
  if [[ ! -f "$PINS_FILE" ]]; then
    warn "No pins configured"
    return 0
  fi
  local tmp; tmp=$(mktemp "${PINS_FILE}.XXXXXX")
  local escaped_p; escaped_p=$(printf '%s' "$provider" | sed 's/[.[\*^$]/\\&/g')
  grep -v "^${escaped_p}=" "$PINS_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$PINS_FILE"
  success "Unpinned $provider (will use registry/default)"
  suggest_next "Apply to launcher: ${GREEN}ccswitch models apply${NC}"
}
