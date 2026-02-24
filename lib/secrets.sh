#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Secrets Library - Secrets Management Functions
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains functions for loading, saving, and managing API keys and secrets.
#
# Requires: lib/utils.sh (for logging functions)
#           lib/validation.sh (for validation functions)
#           lib/core.sh (for SECRETS_FILE constant)
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

# Source utils.sh for logging functions
if [[ -z "${CCSWITCH_UTILS_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
fi

# Source validation.sh for validation functions
if [[ -z "${CCSWITCH_VALIDATION_LOADED:-}" ]]; then
  source "${SCRIPT_DIR}/validation.sh"
fi

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
  # Parse and assign each variable explicitly (never source)
  local line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((++line_num))
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
      error "Invalid line in secrets file at line $line_num: malformed variable assignment"
      return 1
    fi
    local key="${line%%=*}"
    local value="${line#*=}"
    # Remove surrounding quotes if present (handles printf %q output)
    if [[ "$value" =~ ^\$\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$SECRETS_FILE"
}

save_secret() {
  local key="$1" value="$2"
  mkdir -p "$(dirname "$SECRETS_FILE")"
  local tmp; tmp=$(mktemp "${SECRETS_FILE}.XXXXXX")
  if [[ -f "$SECRETS_FILE" ]]; then
    local escaped_key; escaped_key=$(printf '%s' "$key" | sed 's/[.[\*^$]/\\&/g')
    grep -v "^${escaped_key}=" "$SECRETS_FILE" > "$tmp" 2>/dev/null || true
  fi
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
  local escaped_key; escaped_key=$(printf '%s' "$key" | sed 's/[.[\*^$]/\\&/g')
  grep -v "^${escaped_key}=" "$SECRETS_FILE" > "$tmp" 2>/dev/null || true
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
