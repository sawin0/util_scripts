#!/usr/bin/env bash

# ==============================================================================
# Dev Cleaner - Comprehensive Mac Developer Cleanup
# ==============================================================================
# A professional tool to reclaim disk space by clearing developer and system 
# caches while preserving project source code and critical data.
# ==============================================================================

set -uo pipefail

# --- Constants & Configuration ---
VERSION="3.0.0"
DARWIN_CACHE_DIR=$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || echo "")
LIB_CACHE_DIR="$HOME/Library/Caches"
XCODE_DEV_DIR="$HOME/Library/Developer/Xcode"
SIM_DIR="$HOME/Library/Developer/CoreSimulator"

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
SELECTED_MODULES=()

# --- Module Registry ---
# Key: ID
# Value: Descriptive Name | Check Command | Pre-Cleanup Command | Cache Paths (comma separated)
declare -A MODULES
MODULES[xcode]="Xcode Data|xcode-select||$XCODE_DEV_DIR/DerivedData/*,$XCODE_DEV_DIR/Archives/*,$XCODE_DEV_DIR/iOS DeviceSupport/*,$XCODE_DEV_DIR/Logs/*,$LIB_CACHE_DIR/com.apple.dt.Xcode"
MODULES[simulators]="iOS Simulators|||$SIM_DIR/Caches,$SIM_DIR/Devices/*/data/Library/Caches"
MODULES[brew]="Homebrew|brew|brew cleanup -s; brew bundle cleanup --force|$LIB_CACHE_DIR/Homebrew"
MODULES[pods]="CocoaPods|pod|pod cache clean --all|$LIB_CACHE_DIR/CocoaPods"
MODULES[node]="NPM & Yarn|npm||$HOME/.npm/_cacache"
MODULES[yarn]="Yarn|yarn|yarn cache clean|"
MODULES[pnpm]="pnpm|pnpm|pnpm store prune|"
MODULES[bun]="Bun|bun|bun pm cache clean|$HOME/.bun/install/cache/*"
MODULES[go]="Go|go|go clean -cache -modcache|"
MODULES[flutter]="Flutter/Dart|flutter|flutter pub cache clean --force|"
MODULES[dart]="Dart|dart|dart pub cache clean --force|"
MODULES[swift]="Swift PM|||$LIB_CACHE_DIR/org.swift.swiftpm,$XCODE_DEV_DIR/DerivedData/*/SourcePackages"
MODULES[vscode]="VS Code|||$HOME/Library/Application Support/Code/Cache/*,$HOME/Library/Application Support/Code/CachedData/*,$HOME/Library/Application Support/Code/logs/*"
MODULES[docker]="Docker|docker|docker system prune -f -a|"
MODULES[android]="Android & Gradle|||$HOME/.gradle/caches,$HOME/.android/build-cache,$LIB_CACHE_DIR/Google/AndroidStudio*"
MODULES[python]="Python|||**/__pycache__,**/.pytest_cache,$HOME/Library/Caches/pip"
MODULES[system]="System Caches|||$LIB_CACHE_DIR/*,$HOME/Library/Logs/*,$HOME/.Trash/*"

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

size_of() {
    local path="$1"
    # Special handling for wildcards to avoid shell expansion issues in du
    if [[ "$path" == *"*"* ]]; then
        # Use find to get the size of objects matching the glob
        # We need to be careful with eval/globbing
        (
            shopt -s globstar nullglob
            # shellcheck disable=SC2086
            du -sk $path 2>/dev/null | awk '{sum+=$1} END {print sum+0}'
        )
    elif [[ -e "$path" ]]; then
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

validate_path() {
    local path="$1"
    # Basic safety checks
    [[ -z "$path" ]] && return 1
    [[ "$path" == "/" ]] && return 1
    [[ "$path" == "$HOME" ]] && return 1
    [[ "$path" == "$HOME/Documents" ]] && return 1
    [[ "$path" == "$HOME/Desktop" ]] && return 1
    
    # Ensure it's in a known cache/temp directory
    if [[ "$path" == "$HOME/Library/Caches"* ]] || \
       [[ "$path" == "$HOME/Library/Developer"* ]] || \
       [[ "$path" == "$HOME/Library/Logs"* ]] || \
       [[ "$path" == "$HOME/Library/Application Support/Code"* ]] || \
       [[ "$path" == "$HOME/.npm"* ]] || \
       [[ "$path" == "$HOME/.gradle"* ]] || \
       [[ "$path" == "$HOME/.android"* ]] || \
       [[ "$path" == "$HOME/.bun"* ]] || \
       [[ "$path" == "$HOME/.Trash"* ]] || \
       [[ "$path" == "/var/folders/"* ]]; then
        return 0
    fi
    
    # Handle relative-looking patterns like **/__pycache__
    if [[ "$path" == "**/"* ]]; then
        return 0
    fi

    return 1
}

run_cleanup_cmd() {
    local cmd="$1"
    local name="$2"
    if $DRY_RUN; then
        log "[Dry-Run] Would run: $cmd"
    else
        log "Running $name cleanup command: $cmd"
        # Split command and arguments properly if needed, but eval is easier for complex pipes
        eval "$cmd" 2>/dev/null || warn "Command failed: $cmd"
    fi
}

usage() {
    cat <<EOF
Dev Cleaner v$VERSION

Usage:
  $(basename "$0") [options]

Options:
  --all           Clean all detected dev modules (default)
  --list          List detected caches and their estimated sizes
  --xcode         Clean Xcode data
  --simulators    Clean iOS simulators
  --brew          Clean Homebrew
  --pods          Clean CocoaPods
  --node          Clean NPM & Yarn
  --bun           Clean Bun
  --pnpm          Clean pnpm
  --go            Clean Go
  --flutter       Clean Flutter/Dart
  --swift         Clean Swift PM
  --vscode        Clean VS Code
  --docker        Clean Docker (system prune)
  --android       Clean Android & Gradle
  --python        Clean Python caches
  --system        Clean system caches & Trash
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
        --xcode|--simulators|--brew|--pods|--node|--bun|--pnpm|--go|--flutter|--dart|--swift|--vscode|--docker|--android|--python|--system)
            CLEAN_ALL=false
            SELECTED_MODULES+=("${1#--}")
            ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--force) FORCE=true ;;
        --log) LOG_FILE="$2"; shift ;;
        -h|--help) usage ;;
        *) warn "Unknown option: $1"; usage ;;
    esac
    shift
done

# --- Execution Logic ---

if $CLEAN_ALL; then
    SELECTED_MODULES=("${!MODULES[@]}")
fi

header "Dev Cleaner v$VERSION"

if [[ -n "$LOG_FILE" ]]; then
    touch "$LOG_FILE" 2>/dev/null || { error "Cannot write to log file: $LOG_FILE"; exit 1; }
    log "Logging to $LOG_FILE"
fi

# Filter modules based on tool existence
FINAL_MODULES=()
for mod in "${SELECTED_MODULES[@]}"; do
    IFS='|' read -r name check cmd paths <<< "${MODULES[$mod]}"
    if [[ -z "$check" ]] || command_exists "$check"; then
        FINAL_MODULES+=("$mod")
    fi
done

# Detect sizes and paths
TOTAL_RECLAIMABLE_KB=0
DETECTED_ITEMS=() # Format: "ModID|Type|Target|SizeKB|Name" (Type: CMD or PATH)

for mod in "${FINAL_MODULES[@]}"; do
    IFS='|' read -r name check cmd paths <<< "${MODULES[$mod]}"
    
    # Handle Commands
    if [[ -n "$cmd" ]]; then
        # Commands are hard to estimate size for, so we just mark them
        DETECTED_ITEMS+=("$mod|CMD|$cmd|0|$name")
    fi

    # Handle Paths
    IFS=',' read -ra ADDR <<< "$paths"
    for p in "${ADDR[@]}"; do
        # We don't resolve paths yet as they might contain wildcards
        sz=$(size_of "$p")
        if [[ "$sz" -gt 0 ]]; then
            DETECTED_ITEMS+=("$mod|PATH|$p|$sz|$name")
            TOTAL_RECLAIMABLE_KB=$((TOTAL_RECLAIMABLE_KB + sz))
        fi
    done
done

# List Mode
if $LIST_MODE; then
    header "Detected Developer Caches"
    if [[ ${#DETECTED_ITEMS[@]} -eq 0 ]]; then
        log "No developer caches detected."
    else
        printf "${BOLD}%-20s %-15s %s${NC}\n" "Module" "Size" "Detail"
        for entry in "${DETECTED_ITEMS[@]}"; do
            IFS='|' read -r mod type target sz name <<< "$entry"
            if [[ "$type" == "PATH" ]]; then
                printf "%-20s %-15s %s\n" "$name" "$(format_size "$sz")" "$target"
            else
                printf "%-20s %-15s %s\n" "$name" "[Command]" "$target"
            fi
        done
        echo ""
        log "Total Reclaimable Space (Paths): $(format_size "$TOTAL_RECLAIMABLE_KB")"
    fi
    exit 0
fi

# Confirmation
if [[ ${#DETECTED_ITEMS[@]} -eq 0 ]]; then
    success "Nothing found to clean."
    exit 0
fi

header "Cleanup Summary"
log "Estimated space to reclaim: $(format_size "$TOTAL_RECLAIMABLE_KB")"
warn "Note: Command-based cleanups (e.g. brew, docker) are not included in the estimate."
[[ "$DRY_RUN" == true ]] && warn "DRY-RUN MODE ENABLED - No changes will be made"

if [[ "$DRY_RUN" == false && "$FORCE" == false ]]; then
    echo -ne "${BOLD}${YELLOW}Proceed with cleanup? (y/N): ${NC}"
    read -r confirm || confirm="n"
    [[ "$confirm" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
fi

# Cleanup
ACTUAL_RECLAIMED_KB=0
for entry in "${DETECTED_ITEMS[@]}"; do
    IFS='|' read -r mod type target sz name <<< "$entry"
    
    if [[ "$type" == "CMD" ]]; then
        run_cleanup_cmd "$target" "$name"
    else
        if validate_path "$target" || [[ "$FORCE" == true ]]; then
            if $DRY_RUN; then
                log "[Dry-Run] Would remove path: $target ($(format_size "$sz"))"
                ACTUAL_RECLAIMED_KB=$((ACTUAL_RECLAIMED_KB + sz))
            else
                log "Cleaning $name: $target ($(format_size "$sz"))..."
                # Use sh -c for wildcard expansion if necessary
                if [[ "$target" == *"*"* ]]; then
                    sh -c "rm -rf $target" 2>/dev/null || warn "Failed to clean: $target"
                else
                    rm -rf "$target" 2>/dev/null || warn "Failed to clean: $target"
                fi
                ACTUAL_RECLAIMED_KB=$((ACTUAL_RECLAIMED_KB + sz))
            fi
        else
            warn "Skipping potentially unsafe path: $target"
        fi
    fi
done

header "Final Summary"
if $DRY_RUN; then
    success "Dry run complete. Potential space to reclaim: $(format_size "$ACTUAL_RECLAIMED_KB")"
else
    success "Cleanup complete! Total disk space reclaimed: ~$(format_size "$ACTUAL_RECLAIMED_KB")"
fi

exit 0
