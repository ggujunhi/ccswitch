#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Default Provider Management
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains the default command for setting/resetting the default provider
# that the 'claude' command will use via a shell function hook or PATH wrapper.
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

# Locate the real claude binary (skipping any ccswitch wrapper)
find_real_claude() {
  # If we already backed up the original, use that
  if [[ -f "$BIN_DIR/claude-original" ]]; then
    echo "$BIN_DIR/claude-original"
    return 0
  fi
  # Otherwise find the current claude binary
  local claude_path
  claude_path=$(command -v claude 2>/dev/null) || true
  if [[ -n "$claude_path" ]]; then
    echo "$claude_path"
    return 0
  fi
  return 1
}

# Check if force mode is currently active
is_force_active() {
  [[ -f "$BIN_DIR/claude-original" ]] && [[ -f "$DATA_DIR/force-mode" ]]
}

cmd_default() {
  local provider="" force_mode=false
  local default_file="$DATA_DIR/default-provider"
  local shell_rc="$HOME/.bashrc"
  [[ "${SHELL##*/}" == "zsh" ]] && shell_rc="$HOME/.zshrc"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f) force_mode=true ;;
      *) provider="$1" ;;
    esac
    shift
  done

  # Show current default
  if [[ -z "$provider" ]]; then
    if [[ -f "$default_file" ]]; then
      local cur; cur=$(cat "$default_file")
      echo -e "Default provider: ${GREEN}$cur${NC}"
    else
      echo -e "No default provider set ${DIM}(using native Anthropic)${NC}"
    fi
    if is_force_active; then
      echo -e "Mode: ${YELLOW}force${NC} (claude binary wrapped)"
    fi
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ${GREEN}ccswitch default <provider>${NC}         Shell hook (current session)"
    echo -e "  ${GREEN}ccswitch default --force <provider>${NC}  Wrap claude binary (all contexts)"
    echo -e "  ${GREEN}ccswitch default reset${NC}              Restore native claude"
    echo
    echo -e "${BOLD}tmux per-pane override:${NC}"
    echo -e "  ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}"
    return 0
  fi

  # Reset
  if [[ "$provider" == "reset" || "$provider" == "none" || "$provider" == "native" ]]; then
    default_reset "$shell_rc" "$default_file"
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

  if [[ "$force_mode" == true ]]; then
    default_force "$provider" "$def"
  else
    default_hook "$provider" "$def" "$shell_rc"
  fi
}

# =============================================================================
# FORCE MODE: Replace claude binary with wrapper
# =============================================================================

default_force() {
  local provider="$1" def="$2"

  local real_claude
  real_claude=$(find_real_claude) || {
    error "Could not find claude binary"
    return 1
  }

  # Back up original if not already done
  if [[ ! -f "$BIN_DIR/claude-original" ]]; then
    log "Backing up claude binary..."
    cp "$real_claude" "$BIN_DIR/claude-original"
    chmod +x "$BIN_DIR/claude-original"
  fi

  # Create wrapper script that replaces the claude binary
  cat > "$BIN_DIR/claude" << 'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
_CCS_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch"
_CCS_BIN="${HOME}/.local/bin"
[[ "$(uname)" == "Darwin" ]] && _CCS_BIN="${HOME}/bin"

# Determine provider: env var > file > native
_PROVIDER="${CCSWITCH_DEFAULT_PROVIDER:-}"
if [[ -z "$_PROVIDER" && -f "$_CCS_DATA/default-provider" ]]; then
  _PROVIDER=$(cat "$_CCS_DATA/default-provider")
fi

# Route to provider launcher or fall back to original binary
if [[ -n "$_PROVIDER" && "$_PROVIDER" != "native" && -x "$_CCS_BIN/ccswitch-$_PROVIDER" ]]; then
  exec "$_CCS_BIN/ccswitch-$_PROVIDER" "$@"
else
  exec "$_CCS_BIN/claude-original" "$@"
fi
WRAPPER
  chmod +x "$BIN_DIR/claude"

  # Mark force mode active
  echo "active" > "$DATA_DIR/force-mode"

  IFS='|' read -r _ _ _ _ description <<< "$def"
  success "Default set to ${BOLD}$provider${NC} (${description:-$provider}) ${YELLOW}[force]${NC}"
  echo
  echo -e "  ${DIM}${SYM_ARROW}${NC} ${GREEN}claude${NC} binary wrapped → routes through ccswitch-$provider"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Works in ALL contexts (OMC, subprocesses, scripts)"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Original backed up as ${DIM}claude-original${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} tmux override: ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Restore: ${GREEN}ccswitch default reset${NC}"
}

# =============================================================================
# HOOK MODE: Shell function (current approach)
# =============================================================================

default_hook() {
  local provider="$1" def="$2" shell_rc="$3"

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
  echo -e "  ${DIM}${SYM_ARROW}${NC} ${GREEN}claude${NC} now uses $provider ${DIM}(shell hook)${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} ${YELLOW}Note:${NC} Only works in interactive shells"
  echo -e "  ${DIM}${SYM_ARROW}${NC} For OMC/subprocesses: ${GREEN}ccswitch default --force $provider${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} tmux override: ${GREEN}export CCSWITCH_DEFAULT_PROVIDER=zai${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Restore: ${GREEN}ccswitch default reset${NC}"
  echo
  warn "Restart your shell or run: ${GREEN}source $shell_rc${NC}"
}

# =============================================================================
# RESET: Restore native claude
# =============================================================================

default_reset() {
  local shell_rc="$1" default_file="$2"

  rm -f "$default_file"

  # Restore force mode: put original binary back
  if is_force_active; then
    log "Restoring original claude binary..."
    rm -f "$BIN_DIR/claude"
    mv "$BIN_DIR/claude-original" "$BIN_DIR/claude"
    rm -f "$DATA_DIR/force-mode"
    success "Restored native claude ${DIM}(binary unwrapped)${NC}"
  else
    success "Restored native claude"
  fi

  # Remove shell hook
  if [[ -f "$shell_rc" ]]; then
    sed -i '/# CCSwitch default provider hook/d; /ccswitch-shell-hook/d' "$shell_rc" 2>/dev/null || true
  fi

  warn "Restart your shell or run: ${GREEN}unset -f claude 2>/dev/null; hash -r${NC}"
}
