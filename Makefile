# Phobos64 OS Build System
# Cross-compiler toolchain integration with Docker

# -----------------------------
# Shell (use bash for pipefail)
# -----------------------------
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# -----------------------------
# Configuration
# -----------------------------
OS_NAME := phobos64
TOOLCHAIN_IMAGE := $(OS_NAME)-toolchain:latest

DOCKER_RUN := docker run --rm --entrypoint "" -v $(PWD):/workspace -w /workspace $(TOOLCHAIN_IMAGE)
DOCKER_RUN_IT := docker run --rm -it --entrypoint "" -v $(PWD):/workspace -w /workspace $(TOOLCHAIN_IMAGE)


# Cross-compiler tools (used inside container)
CC := x86_64-elf-gcc
AS := x86_64-elf-as
LD := x86_64-elf-ld
OBJCOPY := x86_64-elf-objcopy
OBJDUMP := x86_64-elf-objdump

# Build flags
CFLAGS := -std=gnu99 -ffreestanding -O2 -Wall -Wextra -Iinclude
LDFLAGS := -nostdlib

# Directories
SRC_DIR := src
ARCH_DIR := $(SRC_DIR)/arch
KERNEL_DIR := $(SRC_DIR)/kernel
USERSPACE_DIR := userspace
DEMO_DIR := $(USERSPACE_DIR)/demo
DOOM_DIR := $(USERSPACE_DIR)/doom/doomgeneric
BUILD_DIR := build
ISO_DIR := $(BUILD_DIR)/iso
TOOLCHAIN_DIR := toolchain
INCLUDE_DIR := include
SCRIPTS_DIR := scripts
DOCS_DIR := docs

# A hidden "stamp" to represent "build dir prepared"
BUILD_STAMP := $(BUILD_DIR)/.prepared

# Kernel source files
KERNEL_SOURCES := $(KERNEL_DIR)/main.c
KERNEL_OBJECTS := $(patsubst $(KERNEL_DIR)/%.c,$(BUILD_DIR)/%.o,$(KERNEL_SOURCES))

# Architecture source files (if any)
ARCH_SOURCES := $(wildcard $(ARCH_DIR)/x86_64/*.s)
ARCH_OBJECTS := $(patsubst $(ARCH_DIR)/x86_64/%.s,$(BUILD_DIR)/%.o,$(ARCH_SOURCES))

# All objects
ALL_OBJECTS := $(KERNEL_OBJECTS) $(ARCH_OBJECTS)

# -----------------------------
# Defaults & Hygiene
# -----------------------------
.SECONDARY:
.DEFAULT_GOAL := help
MAKEFLAGS += --no-builtin-rules
# Uncomment if you want undefined variable warnings:
# MAKEFLAGS += --warn-undefined-variables

# -----------------------------
# Default target
# -----------------------------
.PHONY: all
all: build

# -----------------------------
# Build the OS
# -----------------------------
.PHONY: build
build: toolchain-check
	@echo "Building Phobos64..."
	$(DOCKER_RUN) make kernel

# -----------------------------
# Build kernel (runs inside container)
# -----------------------------
.PHONY: kernel
kernel: $(BUILD_DIR)/phobos64.elf

# Ensure build dir exists (separate from phony 'build')
$(BUILD_STAMP):
	@mkdir -p $(BUILD_DIR)
	@touch $@

$(BUILD_DIR)/phobos64.elf: $(BUILD_STAMP) $(ALL_OBJECTS)
	@echo "Linking Phobos64 kernel..."
	$(LD) $(LDFLAGS) -T $(SCRIPTS_DIR)/linker.ld -o $@ $(ALL_OBJECTS)
	@echo "✓ Kernel built: $@"
	@echo "Size: $$(du -h $@ | cut -f1)"

# -----------------------------
# Compile kernel C sources
# -----------------------------
$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c | $(BUILD_STAMP)
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# -----------------------------
# Compile architecture assembly sources
# -----------------------------
$(BUILD_DIR)/%.o: $(ARCH_DIR)/x86_64/%.s | $(BUILD_STAMP)
	@echo "Assembling $<..."
	$(AS) $< -o $@

# -----------------------------
# Create bootable image
# -----------------------------
.PHONY: image
image: build
	@echo "Creating bootable ISO..."
	$(DOCKER_RUN) make create-image

.PHONY: create-image
create-image:
	chmod +x $(SCRIPTS_DIR)/build-iso.sh
	$(SCRIPTS_DIR)/build-iso.sh

# -----------------------------
# Run QEMU for testing
# -----------------------------
.PHONY: run
run: image
	@echo "Running Phobos64 in QEMU..."
	$(DOCKER_RUN) qemu-system-x86_64 \
		-cdrom $(BUILD_DIR)/phobos64.iso \
		-m 512M \
		-serial stdio \
		-enable-kvm 2>/dev/null || \
	$(DOCKER_RUN) qemu-system-x86_64 \
		-cdrom $(BUILD_DIR)/phobos64.iso \
		-m 512M \
		-serial stdio

# -----------------------------
# Debug in QEMU (with GDB support)
# -----------------------------
.PHONY: debug
debug: image
	@echo "Running Phobos64 in QEMU with GDB support..."
	$(DOCKER_RUN) qemu-system-x86_64 \
		-cdrom $(BUILD_DIR)/phobos64.iso \
		-m 512M \
		-serial stdio \
		-s -S

# -----------------------------
# Build userspace applications
# -----------------------------
.PHONY: userspace
userspace: toolchain-check demo doom

# Demo apps
.PHONY: demo
demo: toolchain-check
	@echo "Building demo applications..."
	@if [ -f "$(DEMO_DIR)/Makefile" ]; then \
		$(DOCKER_RUN) make -C $(DEMO_DIR) CC=$(CC) CFLAGS="$(CFLAGS)"; \
	else \
		echo "No demo Makefile found - skipping demo build"; \
	fi

# DOOM
.PHONY: doom
doom: toolchain-check
	@echo "Building DOOM for Phobos64..."
	@if [ -f "$(DOOM_DIR)/Makefile.phobos64" ]; then \
		$(DOCKER_RUN) make -C $(DOOM_DIR) -f Makefile.phobos64; \
		echo "✓ DOOM built successfully"; \
	else \
		echo "DOOM not ready - run scripts/get-third-party.sh first"; \
		exit 1; \
	fi

# -----------------------------
# Toolchain image
# -----------------------------
.PHONY: toolchain
toolchain:
	@echo "Building Phobos64 cross-compiler toolchain..."
	docker build -t $(TOOLCHAIN_IMAGE) $(TOOLCHAIN_DIR)/

.PHONY: toolchain-check
toolchain-check:
	@if ! docker image inspect $(TOOLCHAIN_IMAGE) >/dev/null 2>&1; then \
		echo "Toolchain image not found. Building..."; \
		$(MAKE) toolchain; \
	fi

# -----------------------------
# Dev shell & info
# -----------------------------
.PHONY: shell
shell: toolchain-check
	@echo "Starting Phobos64 development shell..."
	$(DOCKER_RUN_IT)

.PHONY: info
info: toolchain-check
	@echo "=== Phobos64 Toolchain Information ==="
	$(DOCKER_RUN) $(CC) --version
	@echo
	$(DOCKER_RUN) $(LD) --version | head -1
	@echo
	$(DOCKER_RUN) ls -la /opt/phobos64-toolchain/bin/

# -----------------------------
# Setup development environment
# -----------------------------
.PHONY: setup
setup:
	@echo "Setting up Phobos64 development environment..."
	chmod +x $(SCRIPTS_DIR)/get-third-party.sh
	$(SCRIPTS_DIR)/get-third-party.sh

# -----------------------------
# Clean targets
# -----------------------------
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	@if [ -f "$(DEMO_DIR)/Makefile" ]; then \
		$(DOCKER_RUN) make -C $(DEMO_DIR) clean || true; \
	fi
	@if [ -f "$(DOOM_DIR)/Makefile.phobos64" ]; then \
		$(DOCKER_RUN) make -C $(DOOM_DIR) -f Makefile.phobos64 clean || true; \
	fi

.PHONY: clean-toolchain
clean-toolchain:
	@echo "Removing Phobos64 toolchain..."
	docker rmi $(TOOLCHAIN_IMAGE) 2>/dev/null || echo "Toolchain image not found"

.PHONY: purge
purge: clean clean-toolchain
	@echo "Phobos64 completely purged from system"

# -----------------------------
# Dev helpers
# -----------------------------
.PHONY: format
format:
	@echo "Formatting source code..."
	@find $(SRC_DIR) $(INCLUDE_DIR) $(USERSPACE_DIR) \
		-name "*.c" -o -name "*.h" -o -name "*.s" \
		| grep -v doomgeneric | xargs clang-format -i || true

.PHONY: docs
docs:
	@echo "Generating documentation..."
	@if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile 2>/dev/null || echo "No Doxyfile found"; \
	else \
		echo "Doxygen not installed - skipping documentation"; \
	fi

.PHONY: analyze
analyze: toolchain-check
	@echo "Analyzing code..."
	$(DOCKER_RUN) $(CC) $(CFLAGS) -fsyntax-only $(KERNEL_SOURCES)
	@echo "✓ Syntax check passed"

.PHONY: objdump
objdump: $(BUILD_DIR)/phobos64.elf
	@echo "Disassembling kernel..."
	$(DOCKER_RUN) $(OBJDUMP) -d $< > $(BUILD_DIR)/kernel.disasm
	@echo "Disassembly saved to $(BUILD_DIR)/kernel.disasm"

.PHONY: nm
nm: $(BUILD_DIR)/phobos64.elf
	@echo "Kernel symbols:"
	$(DOCKER_RUN) nm -n $< | head -20

# -----------------------------
# Initrd
# -----------------------------
.PHONY: initrd
initrd: | $(BUILD_STAMP)
	@echo "Creating initial ramdisk..."
	@mkdir -p $(BUILD_DIR)/initrd
	@if [ -f "$(DOOM_DIR)/doom.elf" ]; then \
		cp $(DOOM_DIR)/doom.elf $(BUILD_DIR)/initrd/; \
	fi
	@if [ -f "$(DOOM_DIR)/../doom1.wad" ]; then \
		cp $(DOOM_DIR)/../doom1.wad $(BUILD_DIR)/initrd/; \
	fi
	@cd $(BUILD_DIR)/initrd && tar -cf ../initrd.tar * && cd ../..
	@echo "✓ Created $(BUILD_DIR)/initrd.tar"

# -----------------------------
# Install dependencies
# -----------------------------
.PHONY: install-deps
install-deps:
	@echo "Installing development dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y \
			docker.io qemu-system-x86 xorriso git build-essential \
			clang-format doxygen; \
	elif command -v pacman >/dev/null 2>&1; then \
		sudo pacman -S --needed docker qemu xorriso git base-devel \
			clang doxygen; \
	else \
		echo "Please install: docker, qemu-system-x86, xorriso, git manually"; \
	fi

# -----------------------------
# Milestone targets
# -----------------------------
.PHONY: m0 m1 m2 m3 m4 m5 m5.2
m0: toolchain image
	@echo "✓ Milestone M0 complete: Toolchain & Boot Skeleton"

m1: m0
	@echo "Building M1: Long Mode & Memory Management"
	$(MAKE) build
	@echo "✓ Milestone M1 complete"

m2: m1
	@echo "Building M2: Framebuffer Graphics & Logging"
	$(MAKE) run
	@echo "✓ Milestone M2 complete"

m3: m2
	@echo "Building M3: Keyboard Input & Cursor"
	$(MAKE) run
	@echo "✓ Milestone M3 complete"

m4: m3 initrd
	@echo "Building M4: Initrd & VFS"
	$(MAKE) image
	@echo "✓ Milestone M4 complete"

m5: m4 userspace
	@echo "Building M5: User ELF Support & Syscalls"
	$(MAKE) image
	@echo "✓ Milestone M5 complete"

m5.2: m5 doom
	@echo "Building M5.2: DOOM Port"
	$(MAKE) image
	@echo "🎮 Milestone M5.2 complete - DOOM is ready!"

# -----------------------------
# Status report
# -----------------------------
.PHONY: status
status:
	@echo "=== Phobos64 Build Status ==="
	@echo "Toolchain: $$(if docker image inspect $(TOOLCHAIN_IMAGE) >/dev/null 2>&1; then echo '✓ Ready'; else echo '✗ Missing'; fi)"
	@echo "Kernel: $$(if [ -f '$(BUILD_DIR)/phobos64.elf' ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@echo "ISO: $$(if [ -f '$(BUILD_DIR)/phobos64.iso' ]; then echo '✓ Ready'; else echo '✗ Not built'; fi)"
	@echo "DOOM: $$(if [ -f '$(DOOM_DIR)/doom.elf' ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@echo "Dependencies: $$(if [ -f 'include/limine.h' ]; then echo '✓ Ready'; else echo '✗ Run make setup'; fi)"

# -----------------------------
# Help
# -----------------------------
.PHONY: help
help:
	@echo "Phobos64 OS Build System"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup         - First time setup (get dependencies)"
	@echo "  make build         - Build the kernel"
	@echo "  make run           - Test in QEMU"
	@echo ""
	@echo "Main Targets:"
	@echo "  build              - Build the OS kernel"
	@echo "  image              - Create bootable ISO"
	@echo "  run                - Run in QEMU"
	@echo "  debug              - Run in QEMU with GDB support"
	@echo "  userspace          - Build all userspace apps"
	@echo "  doom               - Build DOOM port"
	@echo ""
	@echo "Development:"
	@echo "  shell              - Interactive development shell"
	@echo "  setup              - Download dependencies"
	@echo "  format             - Format source code"
	@echo "  analyze            - Syntax check"
	@echo "  docs               - Generate documentation"
	@echo "  status             - Show build status"
	@echo ""
	@echo "Milestones:"
	@echo "  m0                 - Toolchain & Boot (UEFI + Limine)"
	@echo "  m1                 - Long Mode & Memory Management"
	@echo "  m2                 - Framebuffer Graphics"
	@echo "  m3                 - Keyboard Input"
	@echo "  m4                 - Initrd & VFS"
	@echo "  m5                 - User ELF & Syscalls"
	@echo "  m5.2               - DOOM Port 🎮"
	@echo ""
	@echo "Toolchain:"
	@echo "  toolchain          - Build cross-compiler"
	@echo "  info               - Show toolchain info"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean              - Remove build artifacts"
	@echo "  clean-toolchain    - Remove toolchain image"
	@echo "  purge              - Complete cleanup"
	@echo ""
	@echo "Utilities:"
	@echo "  objdump            - Disassemble kernel"
	@echo "  nm                 - Show kernel symbols"
	@echo "  initrd             - Create initial ramdisk"
	@echo "  install-deps       - Install system dependencies"
