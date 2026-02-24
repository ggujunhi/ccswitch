#!/usr/bin/env bash
# =============================================================================
# CCSwitch Build Script
# Concatenates modular source files into a single ccswitch.sh for distribution.
#
# Usage:
#   bash build.sh                    # Build only
#   bash build.sh --release patch    # Bump patch (1.4.4 -> 1.4.5), build, commit, push
#   bash build.sh --release minor    # Bump minor (1.4.4 -> 1.5.0), build, commit, push
#   bash build.sh --release major    # Bump major (1.4.4 -> 2.0.0), build, commit, push
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/ccswitch.sh"
CORE_FILE="$SCRIPT_DIR/lib/core.sh"

# =============================================================================
# VERSION BUMP
# =============================================================================

bump_version() {
  local level="$1"
  local current; current=$(grep -m1 '^readonly VERSION=' "$CORE_FILE" | sed 's/.*="\(.*\)"/\1/')
  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"

  case "$level" in
    patch) patch=$(( patch + 1 )) ;;
    minor) minor=$(( minor + 1 )); patch=0 ;;
    major) major=$(( major + 1 )); minor=0; patch=0 ;;
    *) echo "ERROR: Invalid bump level '$level' (use: patch, minor, major)" >&2; exit 1 ;;
  esac

  local new_version="$major.$minor.$patch"
  sed -i "s/^readonly VERSION=\"$current\"/readonly VERSION=\"$new_version\"/" "$CORE_FILE"
  echo "$new_version"
}

# =============================================================================
# BUILD
# =============================================================================

do_build() {
  echo "Building ccswitch.sh from modules..."

  # Read version from core.sh
  VERSION=$(grep -m1 '^readonly VERSION=' "$CORE_FILE" | sed 's/.*="\(.*\)"/\1/')
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
}

# =============================================================================
# RELEASE
# =============================================================================

do_release() {
  local level="$1"

  # Ensure clean working tree (except ccswitch.sh which we'll rebuild)
  local dirty; dirty=$(git -C "$SCRIPT_DIR" status --porcelain -- ':!ccswitch.sh' 2>/dev/null || true)
  if [[ -n "$dirty" ]]; then
    echo "ERROR: Working tree has uncommitted changes. Commit or stash first:" >&2
    echo "$dirty" >&2
    exit 1
  fi

  # Bump version
  local old_version; old_version=$(grep -m1 '^readonly VERSION=' "$CORE_FILE" | sed 's/.*="\(.*\)"/\1/')
  local new_version; new_version=$(bump_version "$level")
  echo "Version: $old_version -> $new_version"

  # Build
  do_build

  # Commit, tag, push
  git -C "$SCRIPT_DIR" add lib/core.sh ccswitch.sh
  git -C "$SCRIPT_DIR" commit -m "release: v$new_version"
  git -C "$SCRIPT_DIR" tag -a "v$new_version" -m "Release v$new_version"
  git -C "$SCRIPT_DIR" push
  git -C "$SCRIPT_DIR" push --tags

  echo
  echo "Released v$new_version"
  echo "  Users can update: ccswitch update"
}

# =============================================================================
# ENTRY POINT
# =============================================================================

case "${1:-}" in
  --release)
    [[ -z "${2:-}" ]] && { echo "Usage: build.sh --release <patch|minor|major>" >&2; exit 1; }
    do_release "$2"
    ;;
  *)
    do_build
    ;;
esac
