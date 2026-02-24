#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Commands - Install/Uninstall/Update Commands
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains installation, uninstallation, and update commands.
#
# Requires: lib/core.sh (for VERSION, BIN_DIR, CONFIG_DIR, DATA_DIR, CACHE_DIR, etc.)
#           lib/utils.sh (for logging, colors, prompts, confirm, spinner functions)
#           lib/validation.sh (for validation functions, validate_safe_value)
#           lib/secrets.sh (for secret management, SECRETS_FILE, load_secrets)
#           commands/models.sh (for get_provider_def, resolve_model, resolve_model_opts,
#                              fetch_model_registry, is_provider_configured)
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

readonly CCSWITCH_COMMANDS_INSTALL_LOADED=1

# =============================================================================
# MIGRATION FROM CLOTHER
# =============================================================================

migrate_from_clother() {
  local old_data="${XDG_DATA_HOME}/clother"
  local old_config="${XDG_CONFIG_HOME}/clother"
  local old_cache="${XDG_CACHE_HOME}/clother"

  # Check if old clother data exists and new data doesn't
  if [[ -d "$old_data" ]] && [[ ! -f "$SECRETS_FILE" ]]; then
    log "Detected existing Clother installation, migrating..."

    # Migrate data directory
    mkdir -p "$DATA_DIR"
    if [[ -f "$old_data/secrets.env" ]]; then
      # Validate format before migration
      local _mig_valid=true
      while IFS= read -r _mig_line || [[ -n "$_mig_line" ]]; do
        [[ -z "$_mig_line" || "$_mig_line" =~ ^[[:space:]]*# ]] && continue
        if [[ ! "$_mig_line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
          warn "Clother secrets file has unexpected format; migration skipped"
          _mig_valid=false
          break
        fi
      done < "$old_data/secrets.env"
      if [[ "$_mig_valid" == "true" ]]; then
        sed 's/^CLOTHER_/CCSWITCH_/' "$old_data/secrets.env" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
        success "Migrated secrets from Clother"
      fi
    fi
    if [[ -f "$old_data/banner" ]]; then
      cp "$old_data/banner" "$DATA_DIR/banner" 2>/dev/null || true
    fi

    # Migrate config directory
    if [[ -d "$old_config" ]]; then
      mkdir -p "$CONFIG_DIR"
      cp -r "$old_config"/* "$CONFIG_DIR"/ 2>/dev/null || true
      success "Migrated config from Clother"
    fi

    log "Migration complete. Old Clother files preserved at:"
    log "  $old_data"
    log "  $old_config"
    log "Run 'ccswitch uninstall' on old installation separately if desired."
  fi
}

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================

cleanup() {
  local exit_code="${1:-$?}"
  # Kill spinner if still running
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[K" 2>/dev/null || true
  fi
  tput cnorm 2>/dev/null || true  # Show cursor
  exit "$exit_code"
}

# =============================================================================
# UNINSTALL COMMAND
# =============================================================================

cmd_uninstall() {
  echo
  echo -e "${BOLD}Uninstall CCSwitch${NC}"
  echo
  echo "This will remove:"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $CONFIG_DIR"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $DATA_DIR"
  echo -e "  ${DIM}${SYM_ARROW}${NC} $BIN_DIR/ccswitch*"
  echo

  confirm_danger "Remove all CCSwitch files" "delete ccswitch" || return 1

  spinner_start "Removing files..."
  rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$BIN_DIR"/ccswitch-* "$BIN_DIR/ccswitch" 2>/dev/null || true
  spinner_stop 0 "CCSwitch uninstalled"
}

# =============================================================================
# LAUNCHER GENERATORS
# =============================================================================

generate_launcher() {
  local name="$1" keyvar="$2" baseurl="$3" model="$4" model_opts="$5"

  mkdir -p "$BIN_DIR"

  cat > "$BIN_DIR/ccswitch-$name" << 'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo
SECRETS="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/secrets.env"
if [[ -f "$SECRETS" ]]; then
  [[ -L "$SECRETS" ]] && { echo "Error: secrets file is a symlink - refusing for security" >&2; exit 1; }
  local_perms=$(stat -c "%a" "$SECRETS" 2>/dev/null || stat -f "%Lp" "$SECRETS" 2>/dev/null || echo "000")
  [[ "$local_perms" != "600" ]] && { echo "Error: secrets file has unsafe permissions ($local_perms)" >&2; exit 1; }
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" || "$_line" =~ ^[[:space:]]*# ]] && continue
    [[ "$_line" =~ ^[A-Z_][A-Z0-9_]*= ]] || { echo "Error: malformed secrets file" >&2; exit 1; }
    _key="${_line%%=*}"; _val="${_line#*=}"
    [[ "$_val" =~ ^\$\'(.*)\'$ ]] && _val="${BASH_REMATCH[1]}"
    [[ "$_val" =~ ^\'(.*)\'$ ]] && _val="${BASH_REMATCH[1]}"
    [[ "$_val" =~ ^\"(.*)\"$ ]] && _val="${BASH_REMATCH[1]}"
    printf -v "$_key" '%s' "$_val"
    export "$_key"
  done < "$SECRETS"
fi
LAUNCHER

  # Append provider name display
  echo "echo \"    + $name\" && echo" >> "$BIN_DIR/ccswitch-$name"

  if [[ -n "$keyvar" ]]; then
    cat >> "$BIN_DIR/ccswitch-$name" << LAUNCHER
[[ -z "\${$keyvar:-}" ]] && { echo "Error: $keyvar not set. Run 'ccswitch config'" >&2; exit 1; }
export ANTHROPIC_AUTH_TOKEN="\$$keyvar"
LAUNCHER
  fi

  if [[ -n "$baseurl" ]]; then
    validate_safe_value "$baseurl" "base URL" || return 1
    printf 'export ANTHROPIC_BASE_URL=%q\n' "$baseurl" >> "$BIN_DIR/ccswitch-$name"
  fi
  if [[ -n "$model" ]]; then
    validate_safe_value "$model" "model name" || return 1
    printf 'export ANTHROPIC_MODEL=%q\n' "$model" >> "$BIN_DIR/ccswitch-$name"
  fi

  # Parse model_opts
  if [[ -n "$model_opts" ]]; then
    IFS=',' read -ra opts <<< "$model_opts"
    for opt in "${opts[@]}"; do
      IFS='=' read -r key val <<< "$opt"
      validate_safe_value "$val" "model option" || continue
      case "$key" in
        haiku)  printf 'export ANTHROPIC_DEFAULT_HAIKU_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        sonnet) printf 'export ANTHROPIC_DEFAULT_SONNET_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        opus)   printf 'export ANTHROPIC_DEFAULT_OPUS_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        small)  printf 'export ANTHROPIC_SMALL_FAST_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
      esac
    done
  fi

  echo 'exec claude "$@"' >> "$BIN_DIR/ccswitch-$name"
  chmod +x "$BIN_DIR/ccswitch-$name"
}

generate_or_launcher() {
  local name="$1" model="$2"

  mkdir -p "$BIN_DIR"
  validate_safe_value "$model" "model name" || return 1

  cat > "$BIN_DIR/ccswitch-or-$name" << 'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo
SECRETS="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/secrets.env"
if [[ -f "$SECRETS" ]]; then
  [[ -L "$SECRETS" ]] && { echo "Error: secrets file is a symlink - refusing for security" >&2; exit 1; }
  local_perms=$(stat -c "%a" "$SECRETS" 2>/dev/null || stat -f "%Lp" "$SECRETS" 2>/dev/null || echo "000")
  [[ "$local_perms" != "600" ]] && { echo "Error: secrets file has unsafe permissions ($local_perms)" >&2; exit 1; }
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" || "$_line" =~ ^[[:space:]]*# ]] && continue
    [[ "$_line" =~ ^[A-Z_][A-Z0-9_]*= ]] || { echo "Error: malformed secrets file" >&2; exit 1; }
    _key="${_line%%=*}"; _val="${_line#*=}"
    [[ "$_val" =~ ^\$\'(.*)\'$ ]] && _val="${BASH_REMATCH[1]}"
    [[ "$_val" =~ ^\'(.*)\'$ ]] && _val="${BASH_REMATCH[1]}"
    [[ "$_val" =~ ^\"(.*)\"$ ]] && _val="${BASH_REMATCH[1]}"
    printf -v "$_key" '%s' "$_val"
    export "$_key"
  done < "$SECRETS"
fi
[[ -z "${OPENROUTER_API_KEY:-}" ]] && { echo "Error: OPENROUTER_API_KEY not set. Run 'ccswitch config openrouter'" >&2; exit 1; }

# OpenRouter native Anthropic API support
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY=""  # Must be explicitly empty
LAUNCHER

  # Append model exports and name display using printf %q
  {
    echo "echo \"    + OpenRouter: $name\" && echo"
    printf 'export ANTHROPIC_DEFAULT_OPUS_MODEL=%q\n' "$model"
    printf 'export ANTHROPIC_DEFAULT_SONNET_MODEL=%q\n' "$model"
    printf 'export ANTHROPIC_DEFAULT_HAIKU_MODEL=%q\n' "$model"
    printf 'export ANTHROPIC_SMALL_FAST_MODEL=%q\n' "$model"
    echo 'exec claude "$@"'
  } >> "$BIN_DIR/ccswitch-or-$name"

  chmod +x "$BIN_DIR/ccswitch-or-$name"
}

generate_local_launcher() {
  local name="$1" baseurl="$2" auth_token="$3" model="$4" model_opts="$5"

  mkdir -p "$BIN_DIR"

  cat > "$BIN_DIR/ccswitch-$name" << 'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo
LAUNCHER

  # Append name display and exports using printf %q
  echo "echo \"    + $name (local)\" && echo" >> "$BIN_DIR/ccswitch-$name"
  printf 'export ANTHROPIC_BASE_URL=%q\n' "$baseurl" >> "$BIN_DIR/ccswitch-$name"

  if [[ -n "$auth_token" ]]; then
    printf 'export ANTHROPIC_AUTH_TOKEN=%q\n' "$auth_token" >> "$BIN_DIR/ccswitch-$name"
    echo 'export ANTHROPIC_API_KEY=""' >> "$BIN_DIR/ccswitch-$name"
  fi

  if [[ -n "$model" ]]; then
    validate_safe_value "$model" "model name" || return 1
    printf 'export ANTHROPIC_MODEL=%q\n' "$model" >> "$BIN_DIR/ccswitch-$name"
  fi

  # Parse model_opts
  if [[ -n "$model_opts" ]]; then
    IFS=',' read -ra opts <<< "$model_opts"
    for opt in "${opts[@]}"; do
      IFS='=' read -r key val <<< "$opt"
      validate_safe_value "$val" "model option" || continue
      case "$key" in
        haiku)  printf 'export ANTHROPIC_DEFAULT_HAIKU_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        sonnet) printf 'export ANTHROPIC_DEFAULT_SONNET_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        opus)   printf 'export ANTHROPIC_DEFAULT_OPUS_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
        small)  printf 'export ANTHROPIC_SMALL_FAST_MODEL=%q\n' "$val" >> "$BIN_DIR/ccswitch-$name" ;;
      esac
    done
  fi

  echo 'exec claude "$@"' >> "$BIN_DIR/ccswitch-$name"
  chmod +x "$BIN_DIR/ccswitch-$name"
}


# =============================================================================
# INSTALLATION
# =============================================================================

do_install() {
  # Auto-bump patch version in source file on each install
  local install_version="$VERSION"
  if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    local src="${BASH_SOURCE[0]}"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$VERSION"
    patch=$(( patch + 1 ))
    install_version="$major.$minor.$patch"
    sed -i "s/^readonly VERSION=\"$VERSION\"/readonly VERSION=\"$install_version\"/" "$src"
  fi

  [[ "$NO_BANNER" != "1" ]] && echo -e "$BANNER"
  echo -e "${BOLD}CCSwitch $install_version${NC}"
  echo

  migrate_from_clother

  # Check prerequisites BEFORE any destructive operations
  log "Checking for 'claude' command..."
  if ! command -v claude &>/dev/null; then
    error_ctx "E010" "Claude CLI not found" "Checking prerequisites" \
      "The 'claude' command is not installed" \
      "Install: ${CYAN}curl -fsSL https://claude.ai/install.sh | bash${NC}"
    exit 1
  fi
  success "'claude' found"

  # Back up secrets and model pins before cleaning (use DATA_DIR parent, not /tmp)
  local secrets_tmp="" pins_tmp=""
  _cleanup_install_temps() {
    [[ -n "$secrets_tmp" && -f "$secrets_tmp" ]] && rm -f "$secrets_tmp"
    [[ -n "$pins_tmp" && -f "$pins_tmp" ]] && rm -f "$pins_tmp"
  }
  trap '_cleanup_install_temps' RETURN
  if [[ -f "$SECRETS_FILE" ]]; then
    secrets_tmp=$(mktemp "$(dirname "$SECRETS_FILE")/secrets-backup.XXXXXX")
    cp -p "$SECRETS_FILE" "$secrets_tmp"
  fi
  if [[ -f "$PINS_FILE" ]]; then
    pins_tmp=$(mktemp "$(dirname "$PINS_FILE")/pins-backup.XXXXXX")
    cp -p "$PINS_FILE" "$pins_tmp"
  fi

  rm -f "$BIN_DIR/ccswitch" "$BIN_DIR"/ccswitch-* 2>/dev/null || true
  rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" 2>/dev/null || true

  # Create directories (XDG compliant)
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$BIN_DIR"

  # Restore secrets and pins from backup
  if [[ -n "$secrets_tmp" && -f "$secrets_tmp" ]]; then
    mv "$secrets_tmp" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    secrets_tmp=""  # Clear so cleanup trap doesn't try to remove
  fi
  if [[ -n "$pins_tmp" && -f "$pins_tmp" ]]; then
    mv "$pins_tmp" "$PINS_FILE"
    pins_tmp=""
  fi

  # Save banner
  echo "$BANNER" > "$DATA_DIR/banner"

  # Generate main command
  generate_main_command

  # Generate native launcher
  cat > "$BIN_DIR/ccswitch-native" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${CCSWITCH_NO_BANNER:-}" != "1" && -t 1 ]] && cat "${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch/banner" 2>/dev/null && echo "    + native" && echo
exec claude "$@"
EOF
  chmod +x "$BIN_DIR/ccswitch-native"

  # Fetch model registry for latest models
  fetch_model_registry

  # Generate standard launchers (using registry models when available)
  local providers=(zai zai-cn minimax minimax-cn kimi moonshot ve deepseek mimo)
  for p in "${providers[@]}"; do
    local def; def=$(get_provider_def "$p")
    IFS='|' read -r keyvar baseurl _ _ _ <<< "$def"
    local model; model=$(resolve_model "$p")
    local model_opts; model_opts=$(resolve_model_opts "$p")
    generate_launcher "$p" "$keyvar" "$baseurl" "$model" "$model_opts"
  done

  # Generate local launchers (Ollama, LM Studio, llama.cpp)
  generate_local_launcher "ollama" "http://localhost:11434" "ollama" "" ""
  generate_local_launcher "lmstudio" "http://localhost:1234" "lmstudio" "" ""
  generate_local_launcher "llamacpp" "http://localhost:8000" "" "" ""

  # Verify
  if ! "$BIN_DIR/ccswitch" --version &>/dev/null; then
    error "Installation verification failed"
    exit 1
  fi

  success "Installed CCSwitch v${install_version:-$VERSION}"

  # PATH warning
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo
    warn "Add '$BIN_DIR' to PATH:"
    local shell_rc="$HOME/.bashrc"
    [[ "${SHELL##*/}" == "zsh" ]] && shell_rc="$HOME/.zshrc"
    echo -e "  ${YELLOW}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $shell_rc${NC}"
    echo -e "  ${YELLOW}source $shell_rc${NC}"
  fi

  suggest_next \
    "Configure a provider: ${GREEN}ccswitch config${NC}" \
    "Use native Claude: ${GREEN}ccswitch-native${NC}" \
    "View help: ${GREEN}ccswitch --help${NC}"
}

generate_main_command() {
  cat > "$BIN_DIR/ccswitch" << 'MAINEOF'
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

# Re-exec with the full script for complex commands
SCRIPT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ccswitch"
if [[ -f "$SCRIPT_DIR/ccswitch-full.sh" ]]; then
  exec bash "$SCRIPT_DIR/ccswitch-full.sh" "$@"
fi

# Fallback minimal implementation
echo "CCSwitch - Run installer to complete setup"
MAINEOF
  chmod +x "$BIN_DIR/ccswitch"

  # Copy this script as the full implementation
  if [[ ! -f "${BASH_SOURCE[0]:-}" ]]; then
    # Piped execution - download from GitHub
    local dl_tmp; dl_tmp=$(mktemp "$DATA_DIR/ccswitch-dl.XXXXXX")
    if curl -fsSL https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh -o "$dl_tmp" 2>/dev/null \
       && bash -n "$dl_tmp" 2>/dev/null \
       && grep -q 'get_provider_def' "$dl_tmp" \
       && grep -q 'load_secrets' "$dl_tmp"; then
      mv "$dl_tmp" "$DATA_DIR/ccswitch-full.sh"
    else
      rm -f "$dl_tmp"
      error "Download validation failed"
      exit 1
    fi
  else
    cp "${BASH_SOURCE[0]}" "$DATA_DIR/ccswitch-full.sh"
  fi
  chmod +x "$DATA_DIR/ccswitch-full.sh"
}

# =============================================================================
# BANNER
# =============================================================================

read -r -d '' BANNER << 'EOF' || true
   ____ ____ ____          _ _       _
  / ___/ ___/ ___|_      _(_) |_ ___| |__
 | |  | |   \___ \ \ /\ / / | __/ __| '_ \
 | |__| |___ ___) \ V  V /| | || (__| | | |
  \____\____|____/ \_/\_/ |_|\__\___|_| |_|
EOF

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)    [[ -n "${2:-}" && ! "$2" =~ ^- ]] && { show_command_help "$2"; exit 0; }; show_full_help; exit 0 ;;
      -V|--version) show_version; exit 0 ;;
      -v|--verbose) VERBOSE=1 ;;
      -d|--debug)   DEBUG=1; VERBOSE=1 ;;
      -q|--quiet)   QUIET=1 ;;
      -y|--yes)     YES_MODE=1 ;;
      --bin-dir)    [[ -n "${2:-}" ]] || { error "--bin-dir requires a path argument"; exit 1; }; BIN_DIR="$2"; shift ;;
      --no-input)   NO_INPUT=1 ;;
      --no-color)   NO_COLOR=1; setup_colors ;;
      --no-banner)  NO_BANNER=1 ;;
      --json)       OUTPUT_FORMAT=json ;;
      --plain)      OUTPUT_FORMAT=plain; NO_COLOR=1; setup_colors ;;
      --)           shift; REMAINING_ARGS+=("$@"); break ;;
      -*)           error "Unknown option: $1"; echo "Use --help for usage"; exit 1 ;;
      *)            REMAINING_ARGS+=("$1") ;;
    esac
    shift
  done
}

# =============================================================================
# AUTO-UPDATE
# =============================================================================

check_update() {
  # Skip if explicitly disabled or non-interactive
  [[ "${CCSWITCH_NO_UPDATE:-}" == "1" ]] && return 0
  [[ ! -t 1 ]] && return 0

  local stamp_file="$CACHE_DIR/last_update_check"
  mkdir -p "$CACHE_DIR"

  # Only check once per UPDATE_CHECK_INTERVAL
  if [[ -f "$stamp_file" ]]; then
    local last_check
    last_check=$(cat "$stamp_file" 2>/dev/null || echo 0)
    local now; now=$(date +%s)
    if (( now - last_check < UPDATE_CHECK_INTERVAL )); then
      return 0
    fi
  fi

  # Record check time
  date +%s > "$stamp_file"

  # Fetch remote version (timeout 3s, background-safe)
  local remote_version
  remote_version=$(curl -fsSL --max-time 3 "$CCSWITCH_RAW" 2>/dev/null | grep -m1 '^readonly VERSION=' | sed 's/.*="\(.*\)"/\1/') || return 0

  [[ -z "$remote_version" ]] && return 0
  [[ "$remote_version" == "$VERSION" ]] && return 0

  echo
  log "New version available: ${GREEN}v$remote_version${NC} (current: v$VERSION)"
  local do_update="n"
  if [[ "${YES_MODE:-0}" == "1" ]]; then
    do_update="y"
  else
    confirm "Update now?" && do_update="y"
  fi

  if [[ "$do_update" == "y" ]]; then
    do_self_update
    # Exit immediately: the script file was replaced mid-execution
    exit 0
  else
    log "Skip update. Run ${CYAN}ccswitch update${NC} to update manually."
  fi
}

do_self_update() {
  log "Downloading v$VERSION -> latest..."
  mkdir -p "$DATA_DIR"
  local tmp; tmp=$(mktemp "$DATA_DIR/ccswitch-update.XXXXXX")
  if ! curl -fsSL --max-time 15 "$CCSWITCH_RAW" -o "$tmp" 2>/dev/null; then
    error "Download failed"
    rm -f "$tmp"
    return 1
  fi

  # Validate downloaded script
  if ! bash -n "$tmp" 2>/dev/null; then
    error "Downloaded script has syntax errors, aborting update"
    rm -f "$tmp"
    return 1
  fi

  local new_version
  new_version=$(grep -m1 '^readonly VERSION=' "$tmp" | sed 's/.*="\(.*\)"/\1/')
  if [[ -z "$new_version" ]]; then
    error "Could not determine version of downloaded script"
    rm -f "$tmp"
    return 1
  fi

  # Structural integrity check: verify essential markers exist
  local markers=("get_provider_def" "load_secrets" "generate_launcher" "cmd_config" "main")
  for marker in "${markers[@]}"; do
    if ! grep -q "$marker" "$tmp"; then
      error "Downloaded script missing essential function '$marker', aborting"
      rm -f "$tmp"
      return 1
    fi
  done

  # Replace the full script
  cp "$tmp" "$DATA_DIR/ccswitch-full.sh"
  chmod +x "$DATA_DIR/ccswitch-full.sh"
  rm -f "$tmp"

  success "Updated to v$new_version"
  log "Restart ccswitch to use the new version."
}

cmd_update() {
  log "Checking for updates..."
  local remote_version
  remote_version=$(curl -fsSL --max-time 5 "$CCSWITCH_RAW" 2>/dev/null | grep -m1 '^readonly VERSION=' | sed 's/.*="\(.*\)"/\1/') || true

  if [[ -z "$remote_version" ]]; then
    error "Could not reach update server"
    return 1
  fi

  if [[ "$remote_version" == "$VERSION" ]]; then
    success "Already on latest version (v$VERSION)"
    return 0
  fi

  log "New version available: ${GREEN}v$remote_version${NC} (current: v$VERSION)"
  do_self_update
  # Exit immediately: do_self_update replaced ccswitch-full.sh which bash is
  # currently reading by byte offset.  Continuing would read garbled content.
  exit 0
}
