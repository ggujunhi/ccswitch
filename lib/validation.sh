#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Validation Library - Input Validation Functions
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains validation functions for names, URLs, API keys, and safe values.
#
# Requires: lib/utils.sh (for error_ctx, warn, confirm, error functions)
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

# Source utils.sh for logging functions
if [[ -z "${CCSWITCH_UTILS_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
fi

readonly CCSWITCH_VALIDATION_LOADED=1

# =============================================================================
# VALIDATION FUNCTIONS
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
  # Warn on non-localhost http://
  if [[ "$url" =~ ^http:// ]] && [[ ! "$url" =~ ^http://(localhost|127\.) ]]; then
    warn "Insecure URL: API keys will be sent in cleartext over http://"
    confirm "Continue with insecure URL?" || return 1
  fi
  # Reject shell metacharacters in URL
  if [[ ! "$url" =~ ^[a-zA-Z0-9_./:@?%=\&+~-]+$ ]]; then
    error_ctx "E002" "Invalid URL" "Validating: $url" \
      "URL contains unsafe characters" \
      "Provide a URL without shell metacharacters"
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

# Validate that a value is safe to embed in shell scripts
validate_safe_value() {
  local val="$1" context="${2:-value}"
  if [[ ! "$val" =~ ^[a-zA-Z0-9_./:+=-]+$ ]]; then
    error "Unsafe $context rejected: contains shell metacharacters"
    return 1
  fi
}
