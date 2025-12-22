#!/usr/bin/env bash

# ==============================================================================
# Browser Cleaner - macOS Cache Cleanup Utility
# ==============================================================================
# A professional tool to reclaim disk space by clearing browser caches while 
# preserving user data like bookmarks, passwords, and history.
# ==============================================================================

set -uo pipefail

# --- Constants & Configuration ---
VERSION="3.0.0"
DARWIN_CACHE_DIR=$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || echo "")
LIB_CACHE_DIR="$HOME/Library/Caches"

# --- UI & Colors ---
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- State ---
DRY_RUN=false
FORCE=false
LIST_MODE=false
LOG_FILE=""
CLEAN_ALL=true
SELECTED_BROWSERS=()

# --- Browser Registry ---
# Key: ID
# Value: Descriptive Name | Process Names (commas) | Cache Paths (commas)
declare -A BROWSERS
BROWSERS[safari]="Safari|Safari|com.apple.Safari,com.apple.Safari.SafeBrowsing"
BROWSERS[chrome]="Google Chrome|Google Chrome|Google/Chrome,com.google.Chrome"
BROWSERS[canary]="Chrome Canary|Google Chrome Canary|Google/Chrome Canary,com.google.Chrome.canary"
BROWSERS[firefox]="Firefox|firefox|Firefox,org.mozilla.firefox"
BROWSERS[brave]="Brave|Brave Browser|BraveSoftware/Brave-Browser,com.brave.Browser"
BROWSERS[edge]="Edge|Microsoft Edge|Microsoft Edge,com.microsoft.Edge"
BROWSERS[opera]="Opera|Opera|com.operasoftware.Opera"
BROWSERS[arc]="Arc|Arc|company.thebrowser.Browser"
BROWSERS[vivaldi]="Vivaldi|Vivaldi|Vivaldi,com.vivaldi.Vivaldi"
BROWSERS[orion]="Orion|Orion|ext.kagi.Orion"

# --- Utility Functions ---

log()     { 
    local msg="➡️  $*"
    echo -e "${BLUE}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$LOG_FILE"
}
success() { 
    local msg="✅ $*"
    echo -e "${GREEN}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*" >> "$LOG_FILE"
}
warn()    { 
    local msg="⚠️  $*"
    echo -e "${YELLOW}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $*" >> "$LOG_FILE"
}
error()   { 
    local msg="❌ $*"
    echo -e "${RED}${msg}${NC}" >&2
    [[ -n "$LOG_FILE" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
}
header()  { 
    echo -e "\n${BOLD}${BLUE}=== $* ===${NC}"
    [[ -n "$LOG_FILE" ]] && echo -e "\n=== $* ===" >> "$LOG_FILE"
}

size_of() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sk "$path" 2>/dev/null | awk '{print $1}' || echo "0"
    else
        echo "0"
    fi
}

format_size() {
    local kbytes="$1"
    if [ "$kbytes" -ge 1048576 ]; then
        printf "%.2f GB\n" "$(echo "scale=2; $kbytes / 1048576" | bc 2>/dev/null || echo "$((kbytes / 1048576))")"
    elif [ "$kbytes" -ge 1024 ]; then
        printf "%.2f MB\n" "$(echo "scale=2; $kbytes / 1024" | bc 2>/dev/null || echo "$((kbytes / 1024))")"
    else
        echo "${kbytes} KB"
    fi
}

resolve_path() {
    local p="$1"
    if [[ "$p" == /* ]]; then echo "$p"
    elif [[ "$p" == com.* || "$p" == org.* || "$p" == company.* || "$p" == ext.* ]]; then echo "${DARWIN_CACHE_DIR}${p}"
    else echo "${LIB_CACHE_DIR}/${p}"; fi
}

is_running() {
    local processes="$1"
    [[ -z "$processes" ]] && return 1
    IFS=',' read -ra ADDR <<< "$processes"
    for proc in "${ADDR[@]}"; do
        if pgrep -x "$proc" >/dev/null 2>&1; then return 0; fi
    done
    return 1
}

validate_path() {
    local path="$1"
    if [[ -z "$path" || "$path" == "/" || "$path" == "$HOME" ]]; then return 1; fi
    # Safe locations for cache deletion on macOS
    if [[ "$path" == "$LIB_CACHE_DIR"* || "$path" == "$DARWIN_CACHE_DIR"* || "$path" == "/var/folders/"* || "$path" == "$HOME/Library/Caches/"* ]]; then 
        return 0
    fi
    return 1
}

usage() {
    cat <<EOF
Browser Cleaner v$VERSION

Usage:
  $(basename "$0") [options]

Options:
  --all           Clean all detected browsers (default)
  --list          List detected browser caches and their sizes
  --safari        Clean Safari
  --chrome        Clean Google Chrome
  --canary        Clean Chrome Canary
  --firefox       Clean Firefox
  --brave         Clean Brave
  --edge          Clean Microsoft Edge
  --opera         Clean Opera
  --arc           Clean Arc
  --vivaldi       Clean Vivaldi
  --orion         Clean Orion
  -n, --dry-run   Show what would be cleaned without deleting
  -y, --force     Skip confirmation prompt
  --log FILE      Log output to specified file
  -h, --help      Show this help message
EOF
    exit 0
}

# --- Pre-flight Checks ---

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    error "This script should not be run as root."
    exit 2
fi

if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is only compatible with macOS."
    exit 1
fi

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) CLEAN_ALL=true ;;
        --list) LIST_MODE=true ;;
        --safari|--chrome|--canary|--firefox|--brave|--edge|--opera|--arc|--vivaldi|--orion)
            CLEAN_ALL=false
            SELECTED_BROWSERS+=("${1#--}")
            ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--force) FORCE=true ;;
        --log) LOG_FILE="$2"; shift ;;
        -h|--help) usage ;;
        *) warn "Unknown option: $1"; usage ;;
    esac
    shift
done

# --- Execution ---

if $CLEAN_ALL; then
    SELECTED_BROWSERS=("${!BROWSERS[@]}")
fi

header "macOS Browser Cache Cleaner v$VERSION"

if [[ -n "$LOG_FILE" ]]; then
    touch "$LOG_FILE" 2>/dev/null || { error "Cannot write to log file: $LOG_FILE"; exit 1; }
    log "Logging to $LOG_FILE"
fi

# Check for running browsers
RUNNING_BROWSERS=()
for id in "${SELECTED_BROWSERS[@]}"; do
    IFS='|' read -r name procs paths <<< "${BROWSERS[$id]}"
    if is_running "$procs"; then RUNNING_BROWSERS+=("$name"); fi
done

if [[ ${#RUNNING_BROWSERS[@]} -gt 0 ]]; then
    warn "The following browsers are running: ${RUNNING_BROWSERS[*]}"
    if [[ "$FORCE" == false && "$LIST_MODE" == false ]]; then
        echo -ne "${BOLD}${YELLOW}Continue anyway? (y/N): ${NC}"
        read -r confirm || confirm="n"
        [[ "$confirm" =~ ^[Yy]$ ]] || { error "Aborted."; exit 3; }
    fi
fi

# Detect sizes and paths
TOTAL_RECLAIMABLE_KB=0
DETECTED_PATHS=() # Format: "ID|ResolvedPath|SizeKB|Name"

for id in "${SELECTED_BROWSERS[@]}"; do
    IFS='|' read -r name procs paths <<< "${BROWSERS[$id]}"
    IFS=',' read -ra ADDR <<< "$paths"
    for p in "${ADDR[@]}"; do
        resolved=$(resolve_path "$p")
        if [[ -d "$resolved" ]]; then
            sz=$(size_of "$resolved")
            if [[ "$sz" -gt 0 ]]; then
                DETECTED_PATHS+=("$id|$resolved|$sz|$name")
                TOTAL_RECLAIMABLE_KB=$((TOTAL_RECLAIMABLE_KB + sz))
            fi
        fi
    done
done

# List Mode
if $LIST_MODE; then
    header "Detected Browser Caches"
    if [[ ${#DETECTED_PATHS[@]} -eq 0 ]]; then
        log "No browser caches detected."
    else
        printf "${BOLD}%-20s %-15s %s${NC}\n" "Browser" "Size" "Path"
        for entry in "${DETECTED_PATHS[@]}"; do
            IFS='|' read -r id path sz name <<< "$entry"
            printf "%-20s %-15s %s\n" "$name" "$(format_size "$sz")" "$path"
        done
        echo ""
        log "Total Reclaimable Space: $(format_size "$TOTAL_RECLAIMABLE_KB")"
    fi
    exit 0
fi

# Confirmation
if [[ ${#DETECTED_PATHS[@]} -eq 0 ]]; then
    success "No browser caches found to clean."
    exit 0
fi

header "Cleanup Summary"
log "Estimated space to reclaim: $(format_size "$TOTAL_RECLAIMABLE_KB")"
[[ "$DRY_RUN" == true ]] && warn "DRY-RUN MODE ENABLED - No files will be deleted"

if [[ "$DRY_RUN" == false && "$FORCE" == false ]]; then
    echo -ne "${BOLD}${YELLOW}Proceed with cleanup? (y/N): ${NC}"
    read -r confirm || confirm="n"
    [[ "$confirm" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
fi

# Cleanup
ACTUAL_RECLAIMED_KB=0
for entry in "${DETECTED_PATHS[@]}"; do
    IFS='|' read -r id path sz name <<< "$entry"
    if validate_path "$path"; then
        if $DRY_RUN; then
            log "[Dry-Run] Would remove: $path ($(format_size "$sz"))"
            ACTUAL_RECLAIMED_KB=$((ACTUAL_RECLAIMED_KB + sz))
        else
            log "Cleaning $name cache: $path..."
            rm -rf "$path" 2>/dev/null || warn "Failed to remove $path"
            ACTUAL_RECLAIMED_KB=$((ACTUAL_RECLAIMED_KB + sz))
        fi
    else
        warn "Skipping unsafe path: $path"
    fi
done

header "Final Summary"
if $DRY_RUN; then
    success "Dry run complete. Potential space to reclaim: $(format_size "$ACTUAL_RECLAIMED_KB")"
else
    success "Cleanup complete! Total disk space reclaimed: ~$(format_size "$ACTUAL_RECLAIMED_KB")"
fi

exit 0
