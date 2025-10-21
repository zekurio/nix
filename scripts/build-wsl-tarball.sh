#!/usr/bin/env bash
set -e

# NixOS WSL Tarball Build Script
# This script builds a deployable NixOS WSL tarball from the tabris configuration

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SYSTEM="x86_64-linux"
FLAKE_ATTR="${1:-tabris}"
OUTPUT_DIR="${2:-.}"
OUTPUT_FILE="${OUTPUT_DIR}/nixos-wsl-${FLAKE_ATTR}.tar.gz"
TEMP_DIR=$(mktemp -d)

# Helper functions
log_info() {
    echo -e "${BLUE}${NC} $1"
}

log_success() {
    echo -e "${GREEN}${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}${NC} $1"
}

log_error() {
    echo -e "${RED}${NC} $1"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Print usage
usage() {
    cat << EOF
Usage: $(basename "$0") [FLAKE_ATTR] [OUTPUT_DIR]

Build a NixOS WSL tarball for deployment on Windows.

Arguments:
  FLAKE_ATTR    Flake attribute name (default: tabris)
  OUTPUT_DIR    Output directory for tarball (default: current directory)

Examples:
  $(basename "$0")                          # Build tabris to current dir
  $(basename "$0") tabris /tmp              # Build tabris to /tmp
  $(basename "$0") adam /home/user/builds   # Build adam to /home/user/builds

Environment Variables:
  NIX_BUILD_CORES    Number of build cores (default: auto-detected)
  COMPRESS           Compression method: gzip, bzip2, xz (default: gzip)

EOF
    exit 0
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Verify output directory
if [ ! -d "$OUTPUT_DIR" ]; then
    log_warning "Output directory does not exist: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    log_info "Created output directory: $OUTPUT_DIR"
fi

# Verify we're in the flake directory
if [ ! -f "flake.nix" ]; then
    log_error "flake.nix not found in current directory"
    exit 1
fi

# Check if the flake attribute exists
log_info "Verifying flake attribute: $FLAKE_ATTR"
if ! nix flake show --json 2>/dev/null | grep -q "nixosConfigurations.*$FLAKE_ATTR"; then
    log_warning "Could not verify flake attribute, but will attempt to build anyway"
fi

# Display build information
echo ""
log_info "Building NixOS WSL Tarball"
echo "  Configuration: $FLAKE_ATTR"
echo "  System: $SYSTEM"
echo "  Output: $OUTPUT_FILE"
echo ""

# Build the system
log_info "Building NixOS configuration..."
RESULT=$(nix build \
    ".#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" \
    --system "${SYSTEM}" \
    --no-link \
    --print-out-paths 2>&1 | tail -1)

if [ -z "$RESULT" ] || [ ! -d "$RESULT" ]; then
    log_error "Build failed or result not found"
    exit 1
fi

log_success "Build complete"
log_info "System store path: $RESULT"

# Get size information
SIZE=$(du -sh "$RESULT" | cut -f1)
log_info "System size: $SIZE"

# Create the tarball
echo ""
log_info "Creating tarball..."

# Determine compression
COMPRESS="${COMPRESS:-gzip}"
case "$COMPRESS" in
    gzip)
        COMPRESS_OPT="z"
        COMPRESS_DESC="gzip"
        ;;
    bzip2)
        COMPRESS_OPT="j"
        COMPRESS_DESC="bzip2"
        OUTPUT_FILE="${OUTPUT_FILE%.tar.gz}.tar.bz2"
        ;;
    xz)
        COMPRESS_OPT="J"
        COMPRESS_DESC="xz"
        OUTPUT_FILE="${OUTPUT_FILE%.tar.gz}.tar.xz"
        ;;
    none)
        COMPRESS_OPT=""
        COMPRESS_DESC="uncompressed"
        OUTPUT_FILE="${OUTPUT_FILE%.tar.gz}.tar"
        ;;
    *)
        log_error "Unknown compression method: $COMPRESS"
        exit 1
        ;;
esac

log_info "Compression: $COMPRESS_DESC"

# Create tarball with proper permissions
tar --owner=0 --group=0 --numeric-owner \
    -c${COMPRESS_OPT}f "${OUTPUT_FILE}" \
    -C "${RESULT}" \
    . 2>/dev/null || {
    log_error "Failed to create tarball"
    exit 1
}

# Verify tarball
if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Tarball file not found after creation"
    exit 1
fi

TARBALL_SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
log_success "Tarball created: $OUTPUT_FILE (${TARBALL_SIZE})"

# Display deployment instructions
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               WSL Deployment Instructions                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Copy the tarball to your Windows machine:"
echo "   ${OUTPUT_FILE}"
echo ""
echo "2. Open PowerShell as Administrator and run:"
echo "   ${BLUE}wsl --import NixOS-${FLAKE_ATTR} C:\\WSL\\nixos-${FLAKE_ATTR} ${OUTPUT_FILE}${NC}"
echo ""
echo "3. Launch the distribution:"
echo "   ${BLUE}wsl -d NixOS-${FLAKE_ATTR}${NC}"
echo ""
echo "4. On first boot, rebuild the system:"
echo "   ${BLUE}sudo nixos-rebuild switch${NC}"
echo ""
echo "5. (Optional) Create /etc/wsl.conf for WSL configuration:"
echo "   ${BLUE}sudo tee /etc/wsl.conf > /dev/null << 'WSLCONF'"
echo "[boot]"
echo "systemd = true"
echo ""
echo "[interop]"
echo "enabled = true"
echo "appendWindowsPath = true"
echo ""
echo "[user]"
echo "default = nixos"
echo "WSLCONF${NC}"
echo ""
echo "Additional WSL Commands:"
echo "  - List distributions: ${BLUE}wsl --list --all${NC}"
echo "  - Set default: ${BLUE}wsl --set-default NixOS-${FLAKE_ATTR}${NC}"
echo "  - Terminate: ${BLUE}wsl --terminate NixOS-${FLAKE_ATTR}${NC}"
echo "  - Unregister: ${BLUE}wsl --unregister NixOS-${FLAKE_ATTR}${NC}"
echo ""
echo "Documentation: See WSL_BUILD_GUIDE.md for more information"
echo ""

log_success "Build script completed successfully!"
