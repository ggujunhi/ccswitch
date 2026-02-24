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

# Claude settings file
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

# =============================================================================
# DEFAULT PROVIDER COMMAND
# =============================================================================

# Locate the real claude binary (skipping any ccswitch wrapper)
find_real_claude() {
  # Check for backup (with or without .exe for Windows)
  if [[ -f "$BIN_DIR/claude-original.exe" ]]; then
    echo "$BIN_DIR/claude-original.exe"
    return 0
  elif [[ -f "$BIN_DIR/claude-original" ]]; then
    echo "$BIN_DIR/claude-original"
    return 0
  fi
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
  { [[ -f "$BIN_DIR/claude-original" ]] || [[ -f "$BIN_DIR/claude-original.exe" ]]; } && [[ -f "$DATA_DIR/force-mode" ]]
}

# Check if bypass was set by ccswitch
is_bypass_active() {
  [[ -f "$DATA_DIR/bypass-mode" ]]
}

cmd_default() {
  local provider="" force_mode=false bypass_mode=false
  local default_file="$DATA_DIR/default-provider"
  local shell_rc="$HOME/.bashrc"
  [[ "${SHELL##*/}" == "zsh" ]] && shell_rc="$HOME/.zshrc"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f) force_mode=true ;;
      --bypass|-b) bypass_mode=true ;;
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
    local mode_info=""
    is_force_active && mode_info="force"
    is_bypass_active && mode_info="${mode_info:+$mode_info + }bypass"
    [[ -n "$mode_info" ]] && echo -e "Mode: ${YELLOW}$mode_info${NC}"
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ${GREEN}ccswitch default <provider>${NC}                  Shell hook only"
    echo -e "  ${GREEN}ccswitch default --force <provider>${NC}           Wrap claude binary"
    echo -e "  ${GREEN}ccswitch default --force --bypass <provider>${NC}  Wrap + auto-approve tools"
    echo -e "  ${GREEN}ccswitch default reset${NC}                       Restore everything"
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

  # Handle bypass permissions
  if [[ "$bypass_mode" == true ]]; then
    settings_set_bypass
  fi
}

# =============================================================================
# CLAUDE SETTINGS MANAGEMENT
# =============================================================================

# Set bypassPermissions in claude settings
settings_set_bypass() {
  local py_cmd
  py_cmd=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) || {
    error "Python required for JSON manipulation (install python3)"
    return 1
  }

  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

  # Back up current settings if not already saved by ccswitch
  if [[ -f "$CLAUDE_SETTINGS" ]] && [[ ! -f "$DATA_DIR/settings-backup.json" ]]; then
    cp "$CLAUDE_SETTINGS" "$DATA_DIR/settings-backup.json"
  fi

  # Update settings using Python (safe JSON manipulation)
  "$py_cmd" -c "
import json, os, sys

path = os.path.expanduser('$CLAUDE_SETTINGS')
try:
    with open(path, 'r') as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

if 'permissions' not in data:
    data['permissions'] = {}
data['permissions']['defaultMode'] = 'bypassPermissions'

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" || {
    error "Failed to update claude settings"
    return 1
  }

  echo "active" > "$DATA_DIR/bypass-mode"

  echo
  warn "bypassPermissions enabled in ${DIM}~/.claude/settings.json${NC}"
  echo -e "  ${DIM}${SYM_ARROW}${NC} All tool calls auto-approved (deny list still enforced)"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Restore: ${GREEN}ccswitch default reset${NC}"
}

# Remove bypassPermissions from claude settings
settings_remove_bypass() {
  local py_cmd
  py_cmd=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) || return 1

  if [[ -f "$DATA_DIR/settings-backup.json" ]]; then
    # Restore from backup (safest)
    cp "$DATA_DIR/settings-backup.json" "$CLAUDE_SETTINGS"
    rm -f "$DATA_DIR/settings-backup.json"
  elif [[ -f "$CLAUDE_SETTINGS" ]]; then
    # Remove just the defaultMode key
    "$py_cmd" -c "
import json, os

path = os.path.expanduser('$CLAUDE_SETTINGS')
try:
    with open(path, 'r') as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    exit(0)

if 'permissions' in data and 'defaultMode' in data['permissions']:
    del data['permissions']['defaultMode']

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
  fi

  rm -f "$DATA_DIR/bypass-mode"
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

  # Detect Windows .exe binary
  local is_win_exe=false
  if [[ -f "$BIN_DIR/claude.exe" ]]; then
    is_win_exe=true
  fi

  # Back up original if not already done
  if [[ "$is_win_exe" == true ]]; then
    # Windows: claude.exe is a native PE binary
    if [[ ! -f "$BIN_DIR/claude-original.exe" ]]; then
      log "Backing up claude.exe..."
      cp "$BIN_DIR/claude.exe" "$BIN_DIR/claude-original.exe" || {
        error "Could not back up claude.exe"
        return 1
      }
      chmod +x "$BIN_DIR/claude-original.exe"
    fi
    # Rename claude.exe out of the way (rename is allowed on running .exe on modern Windows)
    if [[ -f "$BIN_DIR/claude.exe" ]]; then
      mv "$BIN_DIR/claude.exe" "$BIN_DIR/claude-native.exe" 2>/dev/null || {
        error "Cannot rename claude.exe (it may be running)"
        echo -e "  ${DIM}${SYM_ARROW}${NC} Close Claude Code first, then retry: ${GREEN}ccswitch default -f $provider${NC}"
        return 1
      }
    fi
  else
    # Unix: standard binary
    if [[ ! -f "$BIN_DIR/claude-original" ]]; then
      log "Backing up claude binary..."
      cp "$real_claude" "$BIN_DIR/claude-original"
      chmod +x "$BIN_DIR/claude-original"
    fi
  fi

  # Determine the fallback binary name for the wrapper
  local fallback_bin="claude-original"
  if [[ "$is_win_exe" == true ]]; then
    fallback_bin="claude-original.exe"
  fi

  # Create wrapper script
  # On Windows: claude.exe is renamed away, so 'claude' (no ext) is found first by bash
  # On Unix: rm first to release the inode (avoids "Text file busy" on running binary)
  # Note: shebang is written separately to survive build.sh strip_module
  rm -f "$BIN_DIR/claude"
  printf '%s\n' '#!/usr/bin/env bash' > "$BIN_DIR/claude"
  cat >> "$BIN_DIR/claude" << WRAPPER
set -euo pipefail
_CCS_DATA="\${XDG_DATA_HOME:-\$HOME/.local/share}/ccswitch"
_CCS_BIN="\${HOME}/.local/bin"
[[ "\$(uname)" == "Darwin" ]] && _CCS_BIN="\${HOME}/bin"

# Determine provider: env var > file > native
_PROVIDER="\${CCSWITCH_DEFAULT_PROVIDER:-}"
if [[ -z "\$_PROVIDER" && -f "\$_CCS_DATA/default-provider" ]]; then
  _PROVIDER=\$(cat "\$_CCS_DATA/default-provider")
fi

# Route to provider launcher or fall back to original binary
if [[ -n "\$_PROVIDER" && "\$_PROVIDER" != "native" && -x "\$_CCS_BIN/ccswitch-\$_PROVIDER" ]]; then
  exec "\$_CCS_BIN/ccswitch-\$_PROVIDER" "\$@"
else
  exec "\$_CCS_BIN/$fallback_bin" "\$@"
fi
WRAPPER
  chmod +x "$BIN_DIR/claude"

  # Mark force mode active
  echo "active" > "$DATA_DIR/force-mode"

  IFS='|' read -r _ _ _ _ description <<< "$def"
  success "Default set to ${BOLD}$provider${NC} (${description:-$provider}) ${YELLOW}[force]${NC}"
  echo
  echo -e "  ${DIM}${SYM_ARROW}${NC} ${GREEN}claude${NC} binary wrapped -> routes through ccswitch-$provider"
  echo -e "  ${DIM}${SYM_ARROW}${NC} Works in ALL contexts (OMC, subprocesses, scripts)"
  if [[ "$is_win_exe" == true ]]; then
    echo -e "  ${DIM}${SYM_ARROW}${NC} Original: ${DIM}claude-original.exe${NC} (claude.exe renamed to claude-native.exe)"
  else
    echo -e "  ${DIM}${SYM_ARROW}${NC} Original backed up as ${DIM}claude-original${NC}"
  fi
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
    if [[ -f "$BIN_DIR/claude-original.exe" ]]; then
      # Windows: remove bash wrapper, restore .exe
      rm -f "$BIN_DIR/claude"
      rm -f "$BIN_DIR/claude-native.exe"
      mv "$BIN_DIR/claude-original.exe" "$BIN_DIR/claude.exe"
    else
      rm -f "$BIN_DIR/claude"
      mv "$BIN_DIR/claude-original" "$BIN_DIR/claude"
    fi
    rm -f "$DATA_DIR/force-mode"
    success "Restored native claude ${DIM}(binary unwrapped)${NC}"
  else
    success "Restored native claude"
  fi

  # Restore bypass permissions
  if is_bypass_active; then
    log "Restoring claude permissions..."
    settings_remove_bypass
    success "Removed bypassPermissions"
  fi

  # Remove shell hook
  if [[ -f "$shell_rc" ]]; then
    sed -i '/# CCSwitch default provider hook/d; /ccswitch-shell-hook/d' "$shell_rc" 2>/dev/null || true
  fi

  warn "Restart your shell or run: ${GREEN}unset -f claude 2>/dev/null; hash -r${NC}"
}
