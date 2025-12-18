#!/usr/bin/env bash

# ==============================================================================
# Browser Cleaner - macOS Cache Cleanup Utility
# ==============================================================================
# A professional tool to reclaim disk space by clearing browser caches while 
# preserving user data like bookmarks, passwords, and history.
# ==============================================================================

set -euo pipefail

VERSION="2.0.0"

# --- Configuration & Flags ---
DRY_RUN=false
FORCE=false
CLEAN_ALL=true

# Browser Flags
CLEAN_SAFARI=false
CLEAN_CHROME=false
CLEAN_CHROME_CANARY=false
CLEAN_FIREFOX=false
CLEAN_BRAVE=false
CLEAN_EDGE=false
CLEAN_OPERA=false
CLEAN_ARC=false
CLEAN_VIVALDI=false
CLEAN_ORION=false

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
size_of() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sk "$path" 2>/dev/null | awk '{print $1}' || echo "0"
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

cleanup_path() {
    local path="$1"
    local description="$2"
    
    if [[ -d "$path" ]]; then
        local size_kb
        size_kb=$(size_of "$path")
        
        if [ "$DRY_RUN" = true ]; then
            log "[Dry-Run] Would remove: $description ($(format_size $size_kb))"
        else
            log "Cleaning $description ($(format_size $size_kb))..."
            rm -rf "$path" 2>/dev/null || true
        fi
    fi
}

# --- Usage ---
usage() {
    cat <<EOF
Browser Cleaner v$VERSION

Usage:
  $(basename "$0") [options]

Options:
  --all           Clean all detected browsers (default)
  --safari        Clean Safari cache
  --chrome        Clean Google Chrome cache
  --canary        Clean Google Chrome Canary cache
  --firefox       Clean Firefox cache
  --brave         Clean Brave cache
  --edge          Clean Microsoft Edge cache
  --opera         Clean Opera cache
  --arc           Clean Arc browser cache
  --vivaldi       Clean Vivaldi cache
  --orion         Clean Orion cache
  -n, --dry-run   Show what would be cleaned without deleting
  -y, --force     Skip confirmation prompt
  -h, --help      Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --chrome --safari
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --safari) CLEAN_SAFARI=true; CLEAN_ALL=false ;;
        --chrome) CLEAN_CHROME=true; CLEAN_ALL=false ;;
        --canary) CLEAN_CHROME_CANARY=true; CLEAN_ALL=false ;;
        --firefox) CLEAN_FIREFOX=true; CLEAN_ALL=false ;;
        --brave) CLEAN_BRAVE=true; CLEAN_ALL=false ;;
        --edge) CLEAN_EDGE=true; CLEAN_ALL=false ;;
        --opera) CLEAN_OPERA=true; CLEAN_ALL=false ;;
        --arc) CLEAN_ARC=true; CLEAN_ALL=false ;;
        --vivaldi) CLEAN_VIVALDI=true; CLEAN_ALL=false ;;
        --orion) CLEAN_ORION=true; CLEAN_ALL=false ;;
        --all) CLEAN_ALL=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--force) FORCE=true ;;
        -h|--help) usage ;;
        *) warn "Unknown option: $1"; usage ;;
    esac
    shift
done

# --- Initialize ---
header "Browser Cleaner v$VERSION"
[ "$DRY_RUN" = true ] && warn "DRY-RUN MODE ENABLED - No files will be deleted"

# Display Warning
warn "This tool clears CACHE data only. Bookmarks, Passwords, and History are safe."
warn "Please close all browsers before continuing for a thorough cleanup."
echo ""

# Detect & Summary
echo -e "Categories selected for cleaning:"
$CLEAN_ALL && echo "  - ALL Detected Browsers" || {
    $CLEAN_SAFARI && echo "  - Safari"
    $CLEAN_CHROME && echo "  - Google Chrome"
    $CLEAN_CHROME_CANARY && echo "  - Chrome Canary"
    $CLEAN_FIREFOX && echo "  - Firefox"
    $CLEAN_BRAVE && echo "  - Brave"
    $CLEAN_EDGE && echo "  - Microsoft Edge"
    $CLEAN_OPERA && echo "  - Opera"
    $CLEAN_ARC && echo "  - Arc"
    $CLEAN_VIVALDI && echo "  - Vivaldi"
    $CLEAN_ORION && echo "  - Orion"
}
echo ""

if [[ "$DRY_RUN" = false && "$FORCE" = false ]]; then
    echo -ne "${BOLD}${YELLOW}Are you sure you want to continue? (y/N): ${NC}"
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
fi

# Capture initial free space
INITIAL_FREE_SPACE=$(df -k / | tail -1 | awk '{print $4}')

# --- Execution ---

if $CLEAN_ALL || $CLEAN_SAFARI; then
    cleanup_path "$HOME/Library/Caches/com.apple.Safari" "Safari"
    cleanup_path "$HOME/Library/Caches/com.apple.Safari.SafeBrowsing" "Safari Safe Browsing"
fi

if $CLEAN_ALL || $CLEAN_CHROME; then
    cleanup_path "$HOME/Library/Caches/Google/Chrome" "Google Chrome"
fi

if $CLEAN_ALL || $CLEAN_CHROME_CANARY; then
    cleanup_path "$HOME/Library/Caches/Google/Chrome Canary" "Chrome Canary"
fi

if $CLEAN_ALL || $CLEAN_FIREFOX; then
    cleanup_path "$HOME/Library/Caches/Firefox" "Firefox"
fi

if $CLEAN_ALL || $CLEAN_BRAVE; then
    cleanup_path "$HOME/Library/Caches/BraveSoftware/Brave-Browser" "Brave"
fi

if $CLEAN_ALL || $CLEAN_EDGE; then
    cleanup_path "$HOME/Library/Caches/Microsoft Edge" "Microsoft Edge"
fi

if $CLEAN_ALL || $CLEAN_OPERA; then
    cleanup_path "$HOME/Library/Caches/com.operasoftware.Opera" "Opera"
fi

if $CLEAN_ALL || $CLEAN_ARC; then
    cleanup_path "$HOME/Library/Caches/company.thebrowser.Browser" "Arc"
fi

if $CLEAN_ALL || $CLEAN_VIVALDI; then
    cleanup_path "$HOME/Library/Caches/Vivaldi" "Vivaldi"
fi

if $CLEAN_ALL || $CLEAN_ORION; then
    cleanup_path "$HOME/Library/Caches/ext.kagi.Orion" "Orion"
fi

# --- Finalize ---
header "Summary"
if [ "$DRY_RUN" = true ]; then
    success "Dry run complete. No files were deleted."
else
    FINAL_FREE_SPACE=$(df -k / | tail -1 | awk '{print $4}')
    RECLAIMED_KB=$((FINAL_FREE_SPACE - INITIAL_FREE_SPACE))
    [ "$RECLAIMED_KB" -lt 0 ] && RECLAIMED_KB=0
    
    success "Browser cleanup complete! Total disk space reclaimed: $(format_size $RECLAIMED_KB)"
fi
