# Phobos64 OS Build System
# Cross-compiler toolchain integration with Docker

# Configuration
OS_NAME := phobos64
TOOLCHAIN_IMAGE := $(OS_NAME)-toolchain:latest
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace $(TOOLCHAIN_IMAGE)
DOCKER_RUN_IT := docker run --rm -it -v $(PWD):/workspace -w /workspace $(TOOLCHAIN_IMAGE)

# Cross-compiler tools (used inside container)
CC := x86_64-elf-gcc
AS := x86_64-elf-as
LD := x86_64-elf-ld
OBJCOPY := x86_64-elf-objcopy
OBJDUMP := x86_64-elf-objdump

# Build flags
CFLAGS := -std=gnu99 -ffreestanding -O2 -Wall -Wextra
LDFLAGS := -ffreestanding -O2 -nostdlib

# Directories
SRC_DIR := src
BUILD_DIR := build
ISO_DIR := $(BUILD_DIR)/iso
TOOLCHAIN_DIR := toolchain

# Default target
.PHONY: all
all: build

# Build the OS
.PHONY: build
build: toolchain-check
	@echo "Building Phobos64..."
	$(DOCKER_RUN) make kernel

# Build kernel (runs inside container)
# Build kernel (runs inside container)
.PHONY: kernel
kernel: $(BUILD_DIR)/phobos64.elf

$(BUILD_DIR)/phobos64.elf: $(BUILD_DIR)
	@echo "Compiling Phobos64 kernel..."
	# Your kernel build commands here
	# $(CC) $(CFLAGS) -c $(SRC_DIR)/kernel.c -o $(BUILD_DIR)/kernel.o
	# $(LD) $(LDFLAGS) -o $@ $(BUILD_DIR)/kernel.o

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build toolchain Docker image
.PHONY: toolchain
toolchain:
	@echo "Building Phobos64 cross-compiler toolchain..."
	docker build -t $(TOOLCHAIN_IMAGE) $(TOOLCHAIN_DIR)/

# Check if toolchain image exists
.PHONY: toolchain-check
toolchain-check:
	@if ! docker image inspect $(TOOLCHAIN_IMAGE) >/dev/null 2>&1; then \
		echo "Toolchain image not found. Building..."; \
		$(MAKE) toolchain; \
	fi

# Interactive shell with toolchain
.PHONY: shell
shell: toolchain-check
	@echo "Starting Phobos64 development shell..."
	$(DOCKER_RUN_IT)

# Run QEMU for testing
.PHONY: run
run: build
	@echo "Running Phobos64 in QEMU..."
	$(DOCKER_RUN) qemu-system-x86_64 \
		-drive format=raw,file=$(BUILD_DIR)/phobos64.img \
		-m 512M \
		-serial stdio

# Create bootable image (placeholder)
.PHONY: image
image: build
	@echo "Creating bootable image..."
	$(DOCKER_RUN) make create-image

.PHONY: create-image
create-image:
	# Image creation commands here
	dd if=/dev/zero of=$(BUILD_DIR)/phobos64.img bs=1M count=64

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

# Remove toolchain Docker image
.PHONY: clean-toolchain
clean-toolchain:
	@echo "Removing Phobos64 toolchain..."
	docker rmi $(TOOLCHAIN_IMAGE) 2>/dev/null || echo "Toolchain image not found"

# Complete cleanup
.PHONY: purge
purge: clean clean-toolchain
	@echo "Phobos64 completely purged from system"

# Show toolchain info
.PHONY: info
info: toolchain-check
	@echo "=== Phobos64 Toolchain Information ==="
	$(DOCKER_RUN) x86_64-elf-gcc --version
	@echo
	$(DOCKER_RUN) x86_64-elf-ld --version

# Development helpers
.PHONY: format
format:
	find $(SRC_DIR) -name "*.c" -o -name "*.h" | xargs clang-format -i

.PHONY: help
help:
	@echo "Phobos64 OS Build System"
	@echo ""
	@echo "Main targets:"
	@echo "  build          - Build the OS kernel"
	@echo "  run            - Run Phobos64 in QEMU"
	@echo "  image          - Create bootable ISO image"
	@echo "  userspace      - Build userspace applications"
	@echo ""
	@echo "Toolchain management:"
	@echo "  toolchain      - Build cross-compiler Docker image"
	@echo "  shell          - Interactive development shell"
	@echo "  info           - Show toolchain information"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean          - Remove build artifacts"
	@echo "  clean-toolchain - Remove toolchain Docker image"
	@echo "  purge          - Complete cleanup"
	@echo ""
	@echo "Development:"
	@echo "  setup          - Run initial development setup"
	@echo "  format         - Format source code"
	@echo "  docs           - Generate documentation"
	@echo "  help           - Show this help"
