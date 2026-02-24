#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - List/Info/Status Commands
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains provider listing, info, and status commands.
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

readonly CCSWITCH_COMMANDS_LIST_LOADED=1

# =============================================================================
# PROVIDER LISTING COMMANDS
# =============================================================================

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
