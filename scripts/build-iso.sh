#!/bin/bash
# scripts/build-iso.sh - Build Phobos64 bootable ISO with Limine

set -e

# Configuration
BUILD_DIR="build"
ISO_DIR="$BUILD_DIR/iso"
KERNEL_ELF="$BUILD_DIR/phobos64.elf"
ISO_FILE="$BUILD_DIR/phobos64.iso"
LIMINE_DIR="$BUILD_DIR/limine"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[Build]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

# Download and build Limine
setup_limine() {
    log "Setting up Limine bootloader..."
    
    if [ ! -d "$LIMINE_DIR" ]; then
        log "Cloning Limine..."
        git clone https://github.com/limine-bootloader/limine.git --branch=v7.x-binary --depth=1 "$LIMINE_DIR"
        cd "$LIMINE_DIR"
        make
        cd - >/dev/null
    fi
}

# Create ISO structure
create_iso_structure() {
    log "Creating ISO directory structure..."
    
    # Clean and create ISO directory
    rm -rf "$ISO_DIR"
    mkdir -p "$ISO_DIR"
    
    # Copy kernel
    if [ ! -f "$KERNEL_ELF" ]; then
        warn "Kernel not found at $KERNEL_ELF"
        exit 1
    fi
    
    cp "$KERNEL_ELF" "$ISO_DIR/"
    
    # Copy Limine configuration
    cp limine.conf "$ISO_DIR/"
    
    # Copy Limine bootloader files
    cp "$LIMINE_DIR/limine-bios.sys" "$ISO_DIR/"
    cp "$LIMINE_DIR/limine-bios-cd.bin" "$ISO_DIR/"
    cp "$LIMINE_DIR/limine-uefi-cd.bin" "$ISO_DIR/"
    
    # Create EFI boot structure
    mkdir -p "$ISO_DIR/EFI/BOOT"
    cp "$LIMINE_DIR/BOOTX64.EFI" "$ISO_DIR/EFI/BOOT/"
    cp "$LIMINE_DIR/BOOTIA32.EFI" "$ISO_DIR/EFI/BOOT/"
}

# Build the ISO
build_iso() {
    log "Building bootable ISO..."
    
    # Create the ISO using xorriso
    xorriso -as mkisofs \
        -b limine-bios-cd.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --efi-boot limine-uefi-cd.bin \
        -efi-boot-part --efi-boot-image \
        --protective-msdos-label \
        "$ISO_DIR" -o "$ISO_FILE"
    
    # Install Limine stage1 to the ISO
    "$LIMINE_DIR/limine" bios-install "$ISO_FILE"
    
    log "ISO created: $ISO_FILE"
}

# Main function
main() {
    log "Building Phobos64 bootable ISO..."
    
    # Ensure build directory exists
    mkdir -p "$BUILD_DIR"
    
    setup_limine
    create_iso_structure
    build_iso
    
    log "Build complete!"
    log "To test: qemu-system-x86_64 -cdrom $ISO_FILE -m 512M"
}

# Check dependencies
check_deps() {
    local missing_deps=()
    
    for dep in git make xorriso; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}"
        warn "On Ubuntu/Debian: sudo apt install git build-essential xorriso"
        warn "On Arch: sudo pacman -S git base-devel xorriso"
        exit 1
    fi
}

check_deps
main "$@"
