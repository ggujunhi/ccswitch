#!/usr/bin/env bash
# =============================================================================
# CCSWITCH Core Library - Constants and Global Variables
# =============================================================================
# This file is part of ccswitch and is sourced by the main script.
# It contains core constants, XDG directory setup, and global flags.
#
# Repository: https://github.com/ggujunhi/ccswitch
# License: MIT
# =============================================================================

set -euo pipefail
IFS=$'\n\t'
umask 077

readonly VERSION="1.5.3"
readonly CCSWITCH_DOCS="https://github.com/ggujunhi/ccswitch"
readonly CCSWITCH_RAW="https://raw.githubusercontent.com/ggujunhi/ccswitch/main/ccswitch.sh"
readonly REGISTRY_URL="https://raw.githubusercontent.com/ggujunhi/ccswitch/main/models.json"
readonly UPDATE_CHECK_INTERVAL=86400  # 24 hours

# =============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# =============================================================================

readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Backward compatibility: support CLOTHER_* env vars with deprecation
if [[ -n "${CLOTHER_CONFIG_DIR:-}" ]] && [[ -z "${CCSWITCH_CONFIG_DIR:-}" ]]; then
  CCSWITCH_CONFIG_DIR="$CLOTHER_CONFIG_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_CONFIG_DIR is deprecated, use CCSWITCH_CONFIG_DIR instead" >&2
fi
if [[ -n "${CLOTHER_DATA_DIR:-}" ]] && [[ -z "${CCSWITCH_DATA_DIR:-}" ]]; then
  CCSWITCH_DATA_DIR="$CLOTHER_DATA_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_DATA_DIR is deprecated, use CCSWITCH_DATA_DIR instead" >&2
fi
if [[ -n "${CLOTHER_CACHE_DIR:-}" ]] && [[ -z "${CCSWITCH_CACHE_DIR:-}" ]]; then
  CCSWITCH_CACHE_DIR="$CLOTHER_CACHE_DIR"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_CACHE_DIR is deprecated, use CCSWITCH_CACHE_DIR instead" >&2
fi
if [[ -n "${CLOTHER_BIN:-}" ]] && [[ -z "${CCSWITCH_BIN:-}" ]]; then
  CCSWITCH_BIN="$CLOTHER_BIN"
  echo -e "\033[1;33m\u26a0\033[0m CLOTHER_BIN is deprecated, use CCSWITCH_BIN instead" >&2
fi

readonly CONFIG_DIR="${CCSWITCH_CONFIG_DIR:-$XDG_CONFIG_HOME/ccswitch}"
readonly DATA_DIR="${CCSWITCH_DATA_DIR:-$XDG_DATA_HOME/ccswitch}"
readonly CACHE_DIR="${CCSWITCH_CACHE_DIR:-$XDG_CACHE_HOME/ccswitch}"

# Default bin directory: ~/.local/bin on Linux (XDG standard), ~/bin on macOS
if [[ -z "${CCSWITCH_BIN:-}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    BIN_DIR="$HOME/bin"
  else
    BIN_DIR="$HOME/.local/bin"
  fi
else
  BIN_DIR="$CCSWITCH_BIN"
fi

readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly SECRETS_FILE="$DATA_DIR/secrets.env"

# =============================================================================
# GLOBAL FLAGS (can be set via env vars)
# =============================================================================

VERBOSE="${CCSWITCH_VERBOSE:-0}"
DEBUG="${CCSWITCH_DEBUG:-0}"
QUIET="${CCSWITCH_QUIET:-0}"
YES_MODE="${CCSWITCH_YES:-0}"
NO_INPUT="${CCSWITCH_NO_INPUT:-0}"
NO_BANNER="${CCSWITCH_NO_BANNER:-0}"
OUTPUT_FORMAT="${CCSWITCH_OUTPUT_FORMAT:-human}"  # human, json, plain
DEFAULT_PROVIDER="${CCSWITCH_DEFAULT_PROVIDER:-}"

readonly CCSWITCH_CORE_LOADED=1
