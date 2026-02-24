#!/usr/bin/env bash
# =============================================================================
# CCSwitch Build Script
# Concatenates modular source files into a single ccswitch.sh for distribution.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/ccswitch.sh"

echo "Building ccswitch.sh from modules..."

# Read version from core.sh
VERSION=$(grep -m1 '^readonly VERSION=' "$SCRIPT_DIR/lib/core.sh" | sed 's/.*="\(.*\)"/\1/')
echo "  Version: $VERSION"

# Start with shebang and header
cat > "$OUTPUT" << 'HEADER'
#!/usr/bin/env bash
# =============================================================================
# CCSWITCH - Multi-provider launcher for Claude CLI
# Single-file distribution (built from modular source)
# =============================================================================
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

HEADER

# Helper: strip shebang, header comments, and source guards from module files
strip_module() {
  local file="$1"
  sed -E '
    /^#!/d
    /^# ====/d
    /^# This file is part of/d
    /^# It contains/d
    /^# Requires:/d
    /^# Repository:/d
    /^# License:/d
    /^# ====/d
    /^SCRIPT_DIR=.*BASH_SOURCE/d
    /^CCSWITCH_DIR=.*dirname/d
    /^if \[\[ -z "\$\{CCSWITCH_.*_LOADED/,/^fi$/d
    /^readonly CCSWITCH_.*_LOADED=/d
    /^# Source .*\.sh/d
    /^[[:space:]]*source "\$/d
  ' "$file" | sed '/^$/N;/^\n$/d'  # collapse multiple blank lines
}

# Concatenate in dependency order
{
  echo "# ============================================================================="
  echo "# CORE"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/lib/core.sh"
  echo

  echo "# ============================================================================="
  echo "# UTILS"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/lib/utils.sh"
  echo

  echo "# ============================================================================="
  echo "# VALIDATION"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/lib/validation.sh"
  echo

  echo "# ============================================================================="
  echo "# SECRETS"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/lib/secrets.sh"
  echo

  echo "# ============================================================================="
  echo "# PROVIDER DEFINITIONS & MODELS"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/models.sh"
  echo

  echo "# ============================================================================="
  echo "# CONFIG COMMAND"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/config.sh"
  echo

  echo "# ============================================================================="
  echo "# LIST / INFO / STATUS COMMANDS"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/list.sh"
  echo

  echo "# ============================================================================="
  echo "# DEFAULT PROVIDER COMMAND"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/default.sh"
  echo

  echo "# ============================================================================="
  echo "# TEST COMMAND"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/test.sh"
  echo

  echo "# ============================================================================="
  echo "# INSTALL / UPDATE / UNINSTALL"
  echo "# ============================================================================="
  echo
  strip_module "$SCRIPT_DIR/commands/install.sh"
  echo

  echo "# ============================================================================="
  echo "# MAIN"
  echo "# ============================================================================="
  echo
  # Main function and entry point from ccswitch entry file
  cat << 'MAINBLOCK'
main() {
  parse_args "$@"
  set -- ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}

  local cmd="${1:-}"
  shift || true

  # Auto-update and model check (silent, non-blocking)
  if [[ "$cmd" != "update" && "$cmd" != "uninstall" && "$cmd" != "models" ]]; then
    check_update
    check_model_updates
  fi

  case "$cmd" in
    "")         show_brief_help ;;
    config)     cmd_config "$@" ;;
    list)       cmd_list "$@" ;;
    info)       cmd_info "$@" ;;
    test)       cmd_test "$@" ;;
    keys)       cmd_keys "$@" ;;
    models)     cmd_models "$@" ;;
    status)     cmd_status "$@" ;;
    default)    cmd_default "$@" ;;
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
  if [[ ! -f "${BASH_SOURCE[0]:-}" ]] || [[ ! -f "$BIN_DIR/ccswitch" ]]; then
    do_install
  elif [[ -z "${1:-}" ]]; then
    do_install
  else
    main "$@"
  fi
fi
MAINBLOCK
} >> "$OUTPUT"

chmod +x "$OUTPUT"

# Verify syntax
if bash -n "$OUTPUT" 2>/dev/null; then
  LINES=$(wc -l < "$OUTPUT")
  echo "  Output: $OUTPUT ($LINES lines)"
  echo "  Syntax: OK"
  echo "Build complete."
else
  echo "ERROR: Syntax check failed!" >&2
  bash -n "$OUTPUT"
  exit 1
fi
