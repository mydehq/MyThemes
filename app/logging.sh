#!/bin/env bash

# MyTM Logger
# Centralized logging system with color support and formatting options

#------------ Colors ------------------

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export BOLD='\033[1m'
export NC='\033[0m'

#------------ Log Indentation ------------------

# Indent Tracker
export _LOG_TAB=0

_tab() {
    local indent=""
    if [ "$_LOG_TAB" -gt 0 ]; then
        for ((i=0; i<_LOG_TAB; i++)); do
            indent+="    "
        done
        printf "%s" "$indent"
    fi
}

log.tab.inc() {
    _LOG_TAB=$((_LOG_TAB + 1))
}

log.tab.dec() {
    _LOG_TAB=$((_LOG_TAB - 1))
    [ "$_LOG_TAB" -lt 0 ] && _LOG_TAB=0
}

log.tab.reset() {
    _LOG_TAB=0
}

#------------ Central Logging Function ------------------

# Central logging function
# Usage: _log -l <level> [-b|--bold] <message>
# Levels: debug, info, success, warn, error, fatal
_log() {
    local level="" bold="" message="" color="" icon=""

    # Parse arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -l|--level)
                level="$2"
                shift 2
                ;;
            -b|--bold)
                bold="${BOLD}"
                shift
                ;;
            *)
                message="$1"
                shift
                ;;
        esac
    done

    # Set color and icon based on level
    case "$level" in
        info)
            color="${BLUE}"
            icon="→"
            ;;
        success)
            color="${GREEN}"
            icon="✔"
            ;;
        warn)
            color="${YELLOW}"
            icon="⚠️"
            ;;
        error)
            color="${RED}"
            icon="✗"
            ;;
        fatal)
            color="${RED}"
            icon="❌"
            ;;
        ask)
            color="${YELLOW}"
            icon="?"
            ;;
        debug)
            # Debug is silent for now
            return 0
            ;;
        *)
            color="${NC}"
            icon=" "
            ;;
    esac

    _tab; echo -e "${color}${icon}${NC} ${bold}${message}${NC}" >&2

    # Exit for fatal
    [ "$level" = "fatal" ] && exit 1
}

#------------ Public API ------------------

# _log wrappers
# Usage: log.<level> [-b|--bold] <message>
log.debug()   { _log -l debug "$@"; }
log.info()    { _log -l info "$@"; }
log.success() { _log -l success "$@"; }
log.warn()    { _log -l warn "$@"; }
log.error()   { _log -l error "$@"; }
log.fatal()   { _log -l fatal "$@"; }
