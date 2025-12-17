#!/usr/bin/env bash

# ==============================================================================
# Dev Cleaner - Comprehensive Mac Developer Cleanup
# ==============================================================================
# Merged and enhanced version featuring granular control, disk space reporting,
# and safe cleanup of various developer and system caches.
# ==============================================================================

set -euo pipefail

VERSION="2.1.0"

# --- Configuration & Flags ---
DRY_RUN=false
FORCE=false
CLEAN_XCODE=false
CLEAN_SIM=false
CLEAN_CACHES=false
CLEAN_BREW=false
CLEAN_PODS=false
CLEAN_NODE=false
CLEAN_ANDROID=false
CLEAN_BUN=false
CLEAN_PNPM=false
CLEAN_GO=false
CLEAN_PUB=false
CLEAN_SWIFT=false
CLEAN_VSCODE=false
CLEAN_DOCKER=false
CLEAN_ALL=true

# Path Definitions
XCODE_DIR="$HOME/Library/Developer/Xcode"
SIM_DIR="$HOME/Library/Developer/CoreSimulator"
CACHE_DIR="$HOME/Library/Caches"
LOG_DIR="$HOME/Library/Logs"

# --- UI & Colors ---
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()     { echo -e "${BLUE}➡️  $@${NC}"; }
success() { echo -e "${GREEN}✅ $@${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $@${NC}"; }
error()   { echo -e "${RED}❌ $@${NC}"; }
header()  { echo -e "\n${BOLD}${BLUE}=== $@ ===${NC}"; }

# --- Utility Functions ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

size_of() {
    local path="$1"
    if [[ -e "$path" ]]; then
        # Handle wildcards by checking if any files exist
        if [[ "$path" == *"*"* ]]; then
            # Use find to get total size of expanded wildcard
            find ${path%/*} -name "${path##*/}" -exec du -sk {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0"
        else
            du -sk "$path" 2>/dev/null | awk '{print $1}' || echo "0"
        fi
    else
        echo "0"
    fi
}

format_size() {
    local kbytes="$1"
    if [ "$kbytes" -ge 1048576 ]; then
        echo "$(echo "scale=2; $kbytes / 1048576" | bc) GB"
    elif [ "$kbytes" -ge 1024 ]; then
        echo "$(echo "scale=2; $kbytes / 1024" | bc) MB"
    else
        echo "${kbytes} KB"
    fi
}

TOTAL_KBYTES_CLEARED=0

cleanup_item() {
    local path="$1"
    local description="$2"
    
    # Expand wildcards if present
    local size_kb
    size_kb=$(size_of "$path")
    
    if [[ -e "$path" ]] || [[ "$path" == *"*"* && $(ls $path 2>/dev/null | wc -l) -gt 0 ]]; then
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would remove: $description ($(format_size $size_kb))"
        else
            log "Cleaning: $description ($(format_size $size_kb))"
            # Suppress errors for system folders (Operation not permitted)
            if [[ "$path" == *"*"* ]]; then
                sh -c "rm -rf $path" 2>/dev/null || true
            else
                rm -rf "$path" 2>/dev/null || true
            fi
            TOTAL_KBYTES_CLEARED=$((TOTAL_KBYTES_CLEARED + size_kb))
        fi
    fi
}

# --- Usage ---
usage() {
    cat <<EOF
Dev Cleaner v$VERSION

Usage:
  $(basename "$0") [options]

Options:
  --all           Clean everything (default)
  --xcode         Clean Xcode data (DerivedData, Archives, Logs)
  --simulators    Clean iOS simulators data
  --caches        Clean general user caches
  --brew          Clean Homebrew cache
  --pods          Clean CocoaPods cache
  --node          Clean NPM/Yarn caches
  --bun           Clean Bun cache
  --pnpm          Clean pnpm store
  --go            Clean Go cache
  --pub           Clean Dart/Pub cache
  --swift         Clean Swift PM cache
  --vscode        Clean VS Code caches
  --docker        Clean Docker images/containers (Destructive!)
  -n, --dry-run   Show what would be deleted without deleting
  -y, --force     Skip confirmation prompt
  -h, --help      Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --xcode --simulators
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --xcode) CLEAN_XCODE=true; CLEAN_ALL=false ;;
        --simulators) CLEAN_SIM=true; CLEAN_ALL=false ;;
        --caches) CLEAN_CACHES=true; CLEAN_ALL=false ;;
        --brew) CLEAN_BREW=true; CLEAN_ALL=false ;;
        --pods) CLEAN_PODS=true; CLEAN_ALL=false ;;
        --node) CLEAN_NODE=true; CLEAN_ALL=false ;;
        --bun) CLEAN_BUN=true; CLEAN_ALL=false ;;
        --pnpm) CLEAN_PNPM=true; CLEAN_ALL=false ;;
        --go) CLEAN_GO=true; CLEAN_ALL=false ;;
        --pub) CLEAN_PUB=true; CLEAN_ALL=false ;;
        --swift) CLEAN_SWIFT=true; CLEAN_ALL=false ;;
        --vscode) CLEAN_VSCODE=true; CLEAN_ALL=false ;;
        --docker) CLEAN_DOCKER=true; CLEAN_ALL=false ;;
        --all) CLEAN_ALL=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--force) FORCE=true ;;
        -h|--help) usage ;;
        *) warn "Unknown option: $1"; usage ;;
    esac
    shift
done

# --- Initialize ---
header "Dev Cleaner v$VERSION"
[ "$DRY_RUN" = true ] && warn "DRY-RUN MODE ENABLED - No files will be deleted"

# Display Warning & Selected Categories
echo -e "${BOLD}${RED}WARNING: This script will delete various developer caches and temporary data.${NC}"
echo -e "Categories selected for cleaning:"
$CLEAN_ALL && echo "  - ALL (Everything below)" || {
    $CLEAN_XCODE && echo "  - Xcode Data"
    $CLEAN_SIM && echo "  - iOS Simulators"
    $CLEAN_BREW && echo "  - Homebrew"
    $CLEAN_PODS && echo "  - CocoaPods"
    $CLEAN_NODE && echo "  - NPM & Yarn"
    $CLEAN_BUN && echo "  - Bun"
    $CLEAN_PNPM && echo "  - pnpm"
    $CLEAN_GO && echo "  - Go"
    $CLEAN_PUB && echo "  - Dart & Pub"
    $CLEAN_SWIFT && echo "  - Swift PM"
    $CLEAN_VSCODE && echo "  - VS Code"
    $CLEAN_DOCKER && echo "  - Docker (Prune -a)"
    $CLEAN_CACHES && echo "  - System & App Caches"
}
echo ""

if [[ "$DRY_RUN" = false && "$FORCE" = false ]]; then
    echo -ne "${BOLD}${YELLOW}Are you sure you want to continue? (y/N): ${NC}"
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
fi

# Capture disk free space before cleanup (in KB)
INITIAL_FREE_SPACE=$(df -k / | tail -1 | awk '{print $4}')

# --- Execution ---

if $CLEAN_ALL || $CLEAN_XCODE; then
    header "Xcode & iOS Development"
    cleanup_item "$XCODE_DIR/DerivedData/*" "Xcode DerivedData"
    cleanup_item "$XCODE_DIR/Archives/*" "Xcode Archives"
    cleanup_item "$XCODE_DIR/iOS DeviceSupport/*" "iOS DeviceSupport"
    cleanup_item "$XCODE_DIR/Logs/*" "Xcode Logs"
    cleanup_item "$CACHE_DIR/com.apple.dt.Xcode" "Xcode Caches"
fi

if $CLEAN_ALL || $CLEAN_SIM; then
    header "iOS Simulators"
    cleanup_item "$SIM_DIR/Caches" "Simulator Caches"
    cleanup_item "$SIM_DIR/Devices/*/data/Library/Caches" "Simulator Device Caches"
fi

if $CLEAN_ALL || $CLEAN_BREW; then
    if command_exists brew; then
        header "Homebrew"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: brew cleanup"
        else
            log "Running brew cleanup..."
            brew cleanup -s
            brew bundle cleanup --force 2>/dev/null || true
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_PODS; then
    if command_exists pod; then
        header "CocoaPods"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: pod cache clean --all"
        else
            log "Cleaning CocoaPods cache..."
            pod cache clean --all
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_NODE; then
    header "NPM & Yarn"
    if command_exists npm; then
        cleanup_item "$HOME/.npm/_cacache" "NPM Cache"
    fi
    if command_exists yarn; then
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: yarn cache clean"
        else
            log "Cleaning Yarn cache..."
            yarn cache clean
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_BUN; then
    if command_exists bun; then
        header "Bun"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: bun pm cache clean"
        else
            log "Cleaning Bun cache..."
            bun pm cache clean 2>/dev/null || true
            cleanup_item "$HOME/.bun/install/cache/*" "Bun Install Cache"
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_PNPM; then
    if command_exists pnpm; then
        header "pnpm"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: pnpm store prune"
        else
            log "Pruning pnpm store..."
            pnpm store prune 2>/dev/null || true
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_GO; then
    if command_exists go; then
        header "Go"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: go clean -cache -modcache"
        else
            log "Cleaning Go cache..."
            go clean -cache -modcache 2>/dev/null || true
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_PUB; then
    header "Dart & Pub"
    if command_exists flutter; then
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: flutter pub cache clean"
        else
            log "Cleaning Flutter pub cache..."
            flutter pub cache clean --force 2>/dev/null || true
        fi
    elif command_exists dart; then
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: dart pub cache clean"
        else
            log "Cleaning Dart pub cache..."
            dart pub cache clean --force 2>/dev/null || true
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_SWIFT; then
    header "Swift PM"
    cleanup_item "$CACHE_DIR/org.swift.swiftpm" "Swift PM Cache"
    cleanup_item "$HOME/Library/Developer/Xcode/DerivedData/*/SourcePackages" "Swift PM Source Packages"
fi

if $CLEAN_ALL || $CLEAN_VSCODE; then
    header "VS Code"
    cleanup_item "$HOME/Library/Application Support/Code/Cache/*" "VS Code Cache"
    cleanup_item "$HOME/Library/Application Support/Code/CachedData/*" "VS Code CachedData"
    cleanup_item "$HOME/Library/Application Support/Code/logs/*" "VS Code Logs"
fi

if $CLEAN_ALL || $CLEAN_DOCKER; then
    if command_exists docker; then
        header "Docker"
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would run: docker system prune -f -a"
        else
            log "Pruning Docker (images, containers, networks)..."
            docker system prune -f -a 2>/dev/null || true
        fi
    fi
fi

if $CLEAN_ALL || $CLEAN_ANDROID; then
    header "Android & Gradle"
    cleanup_item "$HOME/.gradle/caches" "Gradle Caches"
    cleanup_item "$HOME/.android/build-cache" "Android Build Cache"
    cleanup_item "$CACHE_DIR/Google/AndroidStudio*" "Android Studio Caches"
fi

if $CLEAN_ALL || $CLEAN_CACHES; then
    header "System & App Caches"
    cleanup_item "$CACHE_DIR/*" "General User Caches"
    cleanup_item "$LOG_DIR/*" "User Logs"
    cleanup_item "$CACHE_DIR/Slack" "Slack Cache"
    cleanup_item "$CACHE_DIR/com.spotify.client" "Spotify Cache"
    
    header "Trash"
    cleanup_item "$HOME/.Trash/*" "System Trash"
fi

# --- Finalize ---
header "Summary"
if [ "$DRY_RUN" = true ]; then
    success "Dry run complete. No files were deleted."
else
    # Capture disk free space after cleanup
    FINAL_FREE_SPACE=$(df -k / | tail -1 | awk '{print $4}')
    
    # Calculate difference
    RECLAIMED_KB=$((FINAL_FREE_SPACE - INITIAL_FREE_SPACE))
    
    # Ensure we don't show negative values if some other process consumed space
    if [ "$RECLAIMED_KB" -lt 0 ]; then
        RECLAIMED_KB=0
    fi
    
    success "Cleanup complete! Total disk space reclaimed: $(format_size $RECLAIMED_KB)"
fi
