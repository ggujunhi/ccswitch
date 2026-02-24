#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Default Provider Management
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains the default command for setting/resetting the default provider
# that the 'claude' command will use via a shell function hook.
#
# Requires: lib/core.sh, lib/utils.sh, commands/models.sh
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

# Source lib files
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CCSWITCH_DIR="${CCSWITCH_DIR:-$(dirname "$SCRIPT_DIR")}"

if [[ -z "${CCSWITCH_CORE_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/core.sh"
fi
if [[ -z "${CCSWITCH_UTILS_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/lib/utils.sh"
fi
if [[ -z "${CCSWITCH_COMMANDS_MODELS_LOADED:-}" ]]; then
  source "${CCSWITCH_DIR}/commands/models.sh"
fi

readonly CCSWITCH_COMMANDS_DEFAULT_LOADED=1

# =============================================================================
# DEFAULT PROVIDER COMMAND
# =============================================================================

cmd_default() {
  local provider="${1:-}"
  local default_file="$DATA_DIR/default-provider"
  local shell_rc="$HOME/.bashrc"
  [[ "${SHELL##*/}" == "zsh" ]] && shell_rc="$HOME/.zshrc"

  # Show current default
  if [[ -z "$provider" ]]; then
    if [[ -f "$default_file" ]]; then
      local cur; cur=$(cat "$default_file")
      echo -e "Default provider: ${GREEN}$cur${NC}"
    else
      echo -e "No default provider set ${DIM}(using native Anthropic)${NC}"
    fi
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ${GREEN}ccswitch default <provider>${NC}  Set default for 'claude'"
    echo -e "  ${GREEN}ccswitch default reset${NC}      Restore native claude"
    echo
    echo -e "${BOLD}tmux per-pane override:${NC}"
    echo -e "  ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}"
    return 0
  fi

  # Reset
  if [[ "$provider" == "reset" || "$provider" == "none" || "$provider" == "native" ]]; then
    rm -f "$default_file"
    # Remove shell hook
    if [[ -f "$shell_rc" ]]; then
      sed -i '/# CCSwitch default provider hook/d; /ccswitch-shell-hook/d' "$shell_rc" 2>/dev/null || true
    fi
    success "Restored native claude"
    warn "Restart your shell or run: ${GREEN}unset -f claude 2>/dev/null; hash -r${NC}"
    return 0
  fi

  # Validate provider
  local def; def=$(get_provider_def "$provider" 2>/dev/null) || true
  if [[ -z "$def" ]]; then
    if [[ ! -x "$BIN_DIR/ccswitch-$provider" ]]; then
      error "Unknown provider: $provider"
      echo -e "Available: native, zai, zai-cn, minimax, minimax-cn, kimi, moonshot, ve, deepseek, mimo"
      return 1
    fi
  fi

  # Save default provider
  echo "$provider" > "$default_file"

  # Generate shell hook script
  cat > "$DATA_DIR/ccswitch-shell-hook.sh" << 'HOOKEOF'
# CCSwitch: override 'claude' to use configured default provider
claude() {
  local _ccs_data="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch"
  local _ccs_bin="${HOME}/.local/bin"
  [[ "$(uname)" == "Darwin" ]] && _ccs_bin="${HOME}/bin"
  local _provider="${CCSWITCH_DEFAULT_PROVIDER:-}"
  if [[ -z "$_provider" && -f "$_ccs_data/default-provider" ]]; then
    _provider=$(cat "$_ccs_data/default-provider")
  fi
  if [[ -n "$_provider" && "$_provider" != "native" && -x "$_ccs_bin/ccswitch-$_provider" ]]; then
    "$_ccs_bin/ccswitch-$_provider" "$@"
  else
    command claude "$@"
  fi
}
HOOKEOF

  # Add to shell rc if not already present
  if ! grep -q 'ccswitch-shell-hook' "$shell_rc" 2>/dev/null; then
    echo >> "$shell_rc"
    echo '# CCSwitch default provider hook' >> "$shell_rc"
    echo "source \"${DATA_DIR}/ccswitch-shell-hook.sh\"" >> "$shell_rc"
  fi

  # Source it now for current session
  source "$DATA_DIR/ccswitch-shell-hook.sh"

  IFS='|' read -r _ _ _ _ description <<< "$def"
  success "Default set to ${BOLD}$provider${NC} (${description:-$provider})"
  echo
  echo -e "  ${DIM}${SYM_ARROW}${NC} ${GREEN}claude${NC} now uses $provider"
  echo -e "  ${DIM}${SYM_ARROW}${NC} tmux override: ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Restore: ${GREEN}ccswitch default reset${NC}"
  echo
  warn "Restart your shell or run: ${GREEN}source $shell_rc${NC}"
}
