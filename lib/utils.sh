#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Utils Library - Logging, Colors, and Prompts
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains TTY detection, color setup, logging functions, and user prompts.
#
# Requires: lib/core.sh (for global flags: VERBOSE, DEBUG, QUIET, OUTPUT_FORMAT,
#           NO_COLOR, YES_MODE, NO_INPUT)
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

# Source core.sh for global flags
if [[ -z "${CCSWITCH_CORE_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/core.sh"
fi

readonly CCSWITCH_UTILS_LOADED=1

# =============================================================================
# TTY & COLOR DETECTION
# =============================================================================

is_tty() { [[ -t 1 ]]; }
is_stdin_tty() { [[ -t 0 ]]; }
is_interactive() { is_tty && is_stdin_tty && [[ "$NO_INPUT" != "1" ]]; }

setup_colors() {
  if is_tty && [[ -z "${NO_COLOR:-}" ]] && [[ "$OUTPUT_FORMAT" == "human" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    MAGENTA=$'\033[0;35m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
  else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
  fi
}

setup_symbols() {
  if [[ "${TERM:-}" == "dumb" ]] || [[ -n "${NO_COLOR:-}" ]]; then
    SYM_OK="[OK]" SYM_ERR="[X]" SYM_WARN="[!]" SYM_INFO=">" SYM_ARROW="->"
    SYM_CHECK="[x]" SYM_UNCHECK="[ ]"
    SYM_SPINNER=("-" "\\" "|" "/")
    BOX_TL="+" BOX_TR="+" BOX_BL="+" BOX_BR="+" BOX_H="-" BOX_V="|"
  else
    SYM_OK="✓" SYM_ERR="✗" SYM_WARN="⚠" SYM_INFO="→" SYM_ARROW="→"
    SYM_CHECK="✓" SYM_UNCHECK="○"
    SYM_SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    BOX_TL="╭" BOX_TR="╮" BOX_BL="╰" BOX_BR="╯" BOX_H="─" BOX_V="│"
  fi
}

# =============================================================================
# LOGGING SYSTEM
# =============================================================================

debug()   { [[ "$DEBUG" == "1" ]] && echo -e "${DIM}[DEBUG] $*${NC}" >&2 || true; }
verbose() { [[ "$VERBOSE" == "1" || "$DEBUG" == "1" ]] && echo -e "${DIM}$*${NC}" >&2 || true; }
log()     { [[ "$QUIET" != "1" ]] && echo -e "${BLUE}${SYM_INFO}${NC} $*" || true; }
success() { echo -e "${GREEN}${SYM_OK}${NC} $*"; }
warn()    { echo -e "${YELLOW}${SYM_WARN}${NC} $*" >&2; }
error()   { echo -e "${RED}${SYM_ERR}${NC} $*" >&2; }

# Error with context, cause, and solution
error_ctx() {
  local code="$1" msg="$2" context="$3" cause="$4" solution="$5"
  echo >&2
  echo -e "${RED}${BOLD}ERROR${NC} ${DIM}[$code]${NC} ${BOLD}$msg${NC}" >&2
  echo -e "  ${DIM}Context:${NC}  $context" >&2
  echo -e "  ${DIM}Cause:${NC}    $cause" >&2
  echo -e "  ${CYAN}Fix:${NC}      $solution" >&2
  echo >&2
}

# Suggest next steps
suggest_next() {
  [[ "$QUIET" == "1" || "$OUTPUT_FORMAT" != "human" ]] && return
  echo -e "\n${BOLD}Next:${NC}"
  for s in "$@"; do echo -e "  ${CYAN}${SYM_ARROW}${NC} $s"; done
}

# =============================================================================
# UI COMPONENTS
# =============================================================================

draw_box() {
  local title="$1" width="${2:-52}"
  local inner=$((width - 2))
  if [[ ${#title} -gt $((inner - 4)) && inner -gt 10 ]]; then
    title="${title:0:$((inner - 7))}..."
  fi
  local pad=$(( (inner - ${#title}) / 2 ))

  # Use printf repeat instead of tr (tr fails with multi-byte UTF-8 on some Linux)
  local hline; printf -v hline "%${inner}s" ""; hline="${hline// /$BOX_H}"
  printf "%s%s%s\n" "$BOX_TL" "$hline" "$BOX_TR"
  printf "%s%${pad}s${BOLD}%s${NC}%$((inner - pad - ${#title}))s%s\n" "$BOX_V" "" "$title" "" "$BOX_V"
  printf "%s%s%s\n" "$BOX_BL" "$hline" "$BOX_BR"
}

draw_separator() {
  local width="${1:-52}"
  local hline; printf -v hline "%${width}s" ""; hline="${hline// /$BOX_H}"
  printf "${DIM}%s${NC}\n" "$hline"
}

spinner_start() {
  local msg="${1:-Working...}"
  _SPINNER_MSG="$msg"
  _SPINNER_PID=""
  if ! is_tty; then
    echo -e "${BLUE}${SYM_INFO}${NC} $msg"
    return
  fi
  (
    local i=0
    while true; do
      printf "\r${BLUE}%s${NC} %s " "${SYM_SPINNER[$((i % ${#SYM_SPINNER[@]}))]}" "$msg"
      ((i++))
      sleep 0.1
    done
  ) &
  _SPINNER_PID=$!
  disown "$_SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
  local exit_code="${1:-0}" msg="${2:-}"
  if [[ -n "${_SPINNER_PID:-}" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    printf "\r\033[K"  # Clear line
  fi
  if [[ -n "$msg" ]]; then
    if [[ "$exit_code" -eq 0 ]]; then success "$msg"; else error "$msg"; fi
  fi
}

# =============================================================================
# INPUT & PROMPTS
# =============================================================================

prompt() {
  local msg="$1" default="${2:-}" var="${3:-REPLY}"
  local prompt_text="$msg"; [[ -n "$default" ]] && prompt_text="$msg [$default]"
  read -r -p "$prompt_text: " "$var" || true
  if [[ -z "${!var}" && -n "$default" ]]; then
    printf -v "$var" "%s" "$default"
  fi
}

prompt_secret() {
  local msg="$1" var="${2:-REPLY}"
  read -rs -p "$msg: " "$var"; echo
}

confirm() {
  local msg="$1" default="${2:-n}"
  [[ "$YES_MODE" == "1" ]] && return 0
  local hint; [[ "$default" =~ ^[Yy] ]] && hint="[Y/n]" || hint="[y/N]"
  local resp; read -r -p "$msg $hint: " resp || true; resp="${resp:-$default}"
  [[ "$resp" =~ ^[Yy] ]] && return 0 || return 1
}

confirm_danger() {
  local action="$1" phrase="${2:-yes}"
  # Never auto-confirm destructive operations (intentionally ignores YES_MODE)
  echo; draw_box "DANGER" 40; echo
  echo -e "${RED}${BOLD}$action${NC}"; echo
  echo -e "Type ${YELLOW}${BOLD}$phrase${NC} to confirm:"
  local resp; read -r resp
  [[ "$resp" == "$phrase" ]]
}

# =============================================================================
# AUTO-INITIALIZE
# =============================================================================

setup_colors
setup_symbols
