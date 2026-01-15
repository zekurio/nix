#!/usr/bin/env bash
# update-hashes.sh - Update hashes in NixOS flake configuration
#
# Usage:
#   ./scripts/update-hashes.sh [component]
#
# Components:
#   opencode     - Update opencode overlay (fetches GitHub + attempts build for FOD hash)
#   jellyseerr   - Update jellyseerr overlay (fetches GitHub develop branch)
#   caddy        - Update caddy plugin hash (attempts build)
#   all          - Update all components (default)
#
# The script will:
#   1. Prefetch GitHub sources and update src hashes
#   2. Attempt builds to discover FOD (fixed-output derivation) hashes
#   3. Automatically substitute the new hashes in the nix files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Extract hash from nix build error output
extract_hash_from_error() {
    local output="$1"
    # Look for "got:" line which contains the actual hash
    echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1
}

# Extract hash from nix-prefetch-github output
extract_github_hash() {
    local output="$1"
    echo "$output" | grep -oP '"hash":\s*"\Ksha256-[A-Za-z0-9+/=]+' | head -1
}

# Replace hash in file
replace_hash() {
    local file="$1"
    local old_hash="$2"
    local new_hash="$3"
    
    if [[ "$old_hash" == "$new_hash" ]]; then
        log_info "Hash unchanged: $old_hash"
        return 0
    fi
    
    sed -i "s|$old_hash|$new_hash|g" "$file"
    log_success "Updated hash: $old_hash -> $new_hash"
}

# Get current hash from file using pattern
get_current_hash() {
    local file="$1"
    local pattern="$2"
    grep -oP "$pattern" "$file" | head -1
}

# Update opencode overlay
update_opencode() {
    log_info "Updating opencode..."
    local file="$REPO_ROOT/overlays/opencode.nix"
    
    if [[ ! -f "$file" ]]; then
        log_error "opencode.nix not found at $file"
        return 1
    fi
    
    # Get current version
    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$file" | head -1)
    log_info "Current opencode version: $current_version"
    
    # Check for latest release
    log_info "Fetching latest opencode release..."
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/anomalyco/opencode/releases/latest" | grep -oP '"tag_name":\s*"v\K[^"]+' | head -1)
    
    if [[ -z "$latest_version" ]]; then
        log_warn "Could not fetch latest version, using current: $current_version"
        latest_version="$current_version"
    else
        log_info "Latest opencode version: $latest_version"
    fi
    
    # Update version in file
    if [[ "$current_version" != "$latest_version" ]]; then
        sed -i "s|version = \"$current_version\"|version = \"$latest_version\"|g" "$file"
        log_success "Updated version: $current_version -> $latest_version"
    fi
    
    # Prefetch GitHub source
    log_info "Prefetching opencode source..."
    local prefetch_output
    prefetch_output=$(nix run nixpkgs#nix-prefetch-github -- anomalyco opencode --rev "v$latest_version" 2>&1) || true
    
    local new_src_hash
    new_src_hash=$(extract_github_hash "$prefetch_output")
    
    if [[ -n "$new_src_hash" ]]; then
        local current_src_hash
        current_src_hash=$(grep -A5 'src = prev.fetchFromGitHub' "$file" | grep -oP 'hash = "\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [[ -n "$current_src_hash" ]]; then
            replace_hash "$file" "$current_src_hash" "$new_src_hash"
        fi
    else
        log_warn "Could not extract source hash from prefetch output"
    fi
    
    # Attempt build to get node_modules FOD hash
    log_info "Attempting build to discover node_modules hash..."
    log_info "(This may take a while and will likely fail - that's expected)"
    
    local build_output
    build_output=$(nix build "$REPO_ROOT#nixosConfigurations.adam.pkgs.opencode" --impure 2>&1) || true
    
    local new_fod_hash
    new_fod_hash=$(extract_hash_from_error "$build_output")
    
    if [[ -n "$new_fod_hash" ]]; then
        local current_fod_hash
        current_fod_hash=$(grep -oP 'outputHash = "\Ksha256-[A-Za-z0-9+/=]+' "$file" | head -1)
        if [[ -n "$current_fod_hash" ]]; then
            replace_hash "$file" "$current_fod_hash" "$new_fod_hash"
            
            # Try building again with new hash
            log_info "Retrying build with updated node_modules hash..."
            build_output=$(nix build "$REPO_ROOT#nixosConfigurations.adam.pkgs.opencode" --impure 2>&1) || true
            
            # Check if there's another hash error (shouldn't be, but just in case)
            new_fod_hash=$(extract_hash_from_error "$build_output")
            if [[ -n "$new_fod_hash" && "$new_fod_hash" != "$current_fod_hash" ]]; then
                replace_hash "$file" "$(grep -oP 'outputHash = "\Ksha256-[A-Za-z0-9+/=]+' "$file" | head -1)" "$new_fod_hash"
            fi
        fi
    else
        log_info "No FOD hash error found - build may have succeeded or failed for other reasons"
    fi
    
    log_success "opencode update complete"
}

# Update jellyseerr overlay
update_jellyseerr() {
    log_info "Updating jellyseerr..."
    local file="$REPO_ROOT/overlays/jellyseerr-develop.nix"
    
    if [[ ! -f "$file" ]]; then
        log_error "jellyseerr-develop.nix not found at $file"
        return 1
    fi
    
    # Prefetch GitHub source (develop branch)
    log_info "Prefetching jellyseerr develop branch..."
    local prefetch_output
    prefetch_output=$(nix run nixpkgs#nix-prefetch-github -- seerr-team seerr --rev develop 2>&1) || true
    
    local new_src_hash
    new_src_hash=$(extract_github_hash "$prefetch_output")
    
    if [[ -n "$new_src_hash" ]]; then
        local current_src_hash
        current_src_hash=$(grep -A5 'src = prev.fetchFromGitHub' "$file" | grep -oP 'hash = "\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [[ -n "$current_src_hash" ]]; then
            replace_hash "$file" "$current_src_hash" "$new_src_hash"
        fi
    else
        log_warn "Could not extract source hash from prefetch output"
    fi
    
    # Attempt build to get pnpmDeps FOD hash
    log_info "Attempting build to discover pnpmDeps hash..."
    log_info "(This may take a while and will likely fail - that's expected)"
    
    local build_output
    build_output=$(nix build "$REPO_ROOT#nixosConfigurations.adam.pkgs.jellyseerr" --impure 2>&1) || true
    
    local new_fod_hash
    new_fod_hash=$(extract_hash_from_error "$build_output")
    
    if [[ -n "$new_fod_hash" ]]; then
        local current_fod_hash
        current_fod_hash=$(grep -A5 'pnpmDeps = prev.fetchPnpmDeps' "$file" | grep -oP 'hash = "\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [[ -n "$current_fod_hash" ]]; then
            replace_hash "$file" "$current_fod_hash" "$new_fod_hash"
            
            # Retry build
            log_info "Retrying build with updated pnpmDeps hash..."
            nix build "$REPO_ROOT#nixosConfigurations.adam.pkgs.jellyseerr" --impure 2>&1 || true
        fi
    else
        log_info "No FOD hash error found - build may have succeeded or failed for other reasons"
    fi
    
    log_success "jellyseerr update complete"
}

# Update caddy plugin hash
update_caddy() {
    log_info "Updating caddy plugin hash..."
    local file="$REPO_ROOT/modules/homelab/services/caddy.nix"
    
    if [[ ! -f "$file" ]]; then
        log_error "caddy.nix not found at $file"
        return 1
    fi
    
    # For caddy, we need to attempt a build and parse the hash error
    log_info "Attempting caddy build to discover plugin hash..."
    log_info "(This will fail if hash is wrong - that's expected)"
    
    # First, set a dummy hash to force recalculation
    local current_hash
    current_hash=$(grep -oP 'hash = "\Ksha256-[A-Za-z0-9+/=]+' "$file" | head -1)
    
    # Temporarily set invalid hash
    sed -i "s|$current_hash|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|g" "$file"
    
    local build_output
    build_output=$(nix build "$REPO_ROOT#nixosConfigurations.adam.config.services.caddy.package" --impure 2>&1) || true
    
    local new_hash
    new_hash=$(extract_hash_from_error "$build_output")
    
    if [[ -n "$new_hash" ]]; then
        sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$new_hash|g" "$file"
        log_success "Updated caddy plugin hash: $current_hash -> $new_hash"
    else
        # Restore original hash if we couldn't get new one
        sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$current_hash|g" "$file"
        log_warn "Could not determine new caddy hash, restored original"
    fi
    
    log_success "caddy update complete"
}

# Main
main() {
    local component="${1:-all}"
    
    log_info "Starting hash update for: $component"
    log_info "Repository root: $REPO_ROOT"
    echo
    
    case "$component" in
        opencode)
            update_opencode
            ;;
        jellyseerr)
            update_jellyseerr
            ;;
        caddy)
            update_caddy
            ;;
        all)
            update_opencode
            echo
            update_jellyseerr
            echo
            update_caddy
            ;;
        *)
            log_error "Unknown component: $component"
            echo "Usage: $0 [opencode|jellyseerr|caddy|all]"
            exit 1
            ;;
    esac
    
    echo
    log_success "All updates complete!"
    log_info "Run 'nix flake check --impure' to verify the configuration"
}

main "$@"
