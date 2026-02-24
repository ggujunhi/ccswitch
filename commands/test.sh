#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Test Provider
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains the test command for testing provider connections.
#
# Requires: lib/core.sh (for VERSION, BIN_DIR, draw_box, draw_separator, etc.)
#           lib/utils.sh (for logging, colors, prompts, confirm)
#           lib/validation.sh (for validation functions)
#           lib/secrets.sh (for secret management, save_secret, load_secrets)
#           commands/models.sh (for get_provider_def, is_provider_configured, resolve_model)
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

readonly CCSWITCH_COMMANDS_TEST_LOADED=1

# =============================================================================
# PROVIDER TEST COMMAND
# =============================================================================

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

    # Test with a real API call to /v1/messages (minimal request, max_tokens=1)
    # Send both x-api-key and Authorization headers (providers vary on which they accept)
    # Use the provider's actual model name, not a hardcoded one
    local api_key="${!keyvar:-}"
    local api_url="${test_url%/}/v1/messages"
    local model; model=$(resolve_model "$p" 2>/dev/null) || model="claude-sonnet-4-20250514"
    local http_code body
    body=$(curl -s --max-time 8 -w "\n%{http_code}" \
      -X POST "$api_url" \
      -H "content-type: application/json" \
      -H "x-api-key: $api_key" \
      -H "Authorization: Bearer $api_key" \
      -H "anthropic-version: 2023-06-01" \
      -d "{\"model\":\"$model\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" \
      2>/dev/null) || body=""
    http_code="${body##*$'\n'}"
    body="${body%$'\n'*}"

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
      echo -e "${GREEN}${SYM_OK} ok${NC} ${DIM}(API key valid)${NC}"
      ((++ok)) || true
    elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
      echo -e "${RED}${SYM_ERR} auth failed${NC} ${DIM}(HTTP $http_code — check API key)${NC}"
      ((++fail)) || true
    elif [[ "$http_code" == "404" ]]; then
      echo -e "${RED}${SYM_ERR} endpoint not found${NC} ${DIM}(HTTP 404 — check base URL)${NC}"
      ((++fail)) || true
    elif [[ "$http_code" =~ ^4[0-9][0-9]$ ]]; then
      # 400, 429, etc. — server is reachable, key accepted but request issue
      echo -e "${GREEN}${SYM_OK} reachable${NC} ${DIM}(HTTP $http_code)${NC}"
      ((++ok)) || true
    elif [[ "$http_code" =~ ^5[0-9][0-9]$ ]]; then
      echo -e "${RED}${SYM_ERR} server error${NC} ${DIM}(HTTP $http_code)${NC}"
      ((++fail)) || true
    else
      # No HTTP response — fall back to TCP connect
      local host; host=$(echo "$test_url" | sed 's|https\?://\([^/:]*\).*|\1|')
      if [[ ! "$host" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo -e "${RED}${SYM_ERR} invalid hostname${NC}"
        ((++fail)) || true
        continue
      fi
      local port=443
      [[ "$test_url" =~ http:// ]] && port=80
      if timeout 3 bash -c "echo >/dev/tcp/\$1/\$2" _ "$host" "$port" 2>/dev/null; then
        echo -e "${YELLOW}${SYM_WARN} TCP ok${NC} ${DIM}(API unreachable)${NC}"
        ((++fail)) || true
      else
        echo -e "${RED}${SYM_ERR} unreachable${NC}"
        ((++fail)) || true
      fi
    fi
  done

  echo
  echo -e "Results: ${GREEN}$ok reachable${NC}, ${RED}$fail failed${NC}$([[ $skip -gt 0 ]] && echo ", ${DIM}$skip skipped${NC}")"
}
