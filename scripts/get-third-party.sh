#!/bin/bash
# scripts/get-third-party.sh - Download and setup third-party dependencies for Phobos64

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[Third-Party]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

info() {
    echo -e "${BLUE}[Info]${NC} $1"
}

# Ensure we're in project root
if [ ! -f "Makefile" ]; then
    echo "Error: Must run from project root directory"
    exit 1
fi

log "Setting up Phobos64 third-party dependencies..."

# 1. Create Limine config
log "Creating Limine bootloader configuration..."
cat > limine.conf << 'EOF'
timeout: 3

:Phobos64 OS
kaslr: no
protocol: limine
kernel_path: boot():/phobos64.elf
resolution: 1024x768
kernel_cmdline: debug
EOF

info "✓ Created limine.conf"

# 2. Download Limine header
log "Downloading Limine protocol header..."
mkdir -p include
if wget -q https://github.com/limine-bootloader/limine/raw/v7.x-binary/limine.h -O include/limine.h; then
    info "✓ Downloaded include/limine.h"
else
    warn "Failed to download limine.h - check internet connection"
    exit 1
fi

# 3. Setup doomgeneric
log "Setting up doomgeneric for DOOM port..."

# Create userspace/doom directory if it doesn't exist
mkdir -p userspace/doom

cd userspace/doom

# Clone doomgeneric if not already present
if [ ! -d "doomgeneric" ]; then
    log "Cloning doomgeneric repository..."
    if git clone https://github.com/ozkl/doomgeneric.git; then
        info "✓ Cloned doomgeneric"
    else
        warn "Failed to clone doomgeneric - check internet connection"
        exit 1
    fi
else
    info "✓ doomgeneric already present"
fi

cd doomgeneric

# Create Phobos64-specific platform
log "Creating Phobos64 platform for doomgeneric..."

cat > doomgeneric_phobos64.c << 'EOF'
// doomgeneric_phobos64.c - Phobos64 OS platform for doomgeneric

#include "doomgeneric.h"
#include <stdint.h>

// Forward declarations for Phobos64 syscalls (to be implemented)
extern void phobos64_blit_screen(uint32_t *pixels);
extern uint32_t phobos64_get_ticks(void);
extern void phobos64_sleep(uint32_t ms);
extern uint32_t phobos64_get_key(void);

// Screen dimensions - will be configurable via syscall
#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480

static uint32_t framebuffer[SCREEN_WIDTH * SCREEN_HEIGHT];

void DG_Init(void)
{
    // Initialize Phobos64 platform
    // This will be called once at startup
}

void DG_DrawFrame(void)
{
    // Blit the DOOM screen to Phobos64 framebuffer
    phobos64_blit_screen(DG_ScreenBuffer);
}

void DG_SleepMs(uint32_t ms)
{
    // Sleep using Phobos64 syscall
    phobos64_sleep(ms);
}

uint32_t DG_GetTicksMs(void)
{
    // Get system ticks from Phobos64
    return phobos64_get_ticks();
}

int DG_GetKey(int* pressed, unsigned char* doomKey)
{
    // Get keyboard input from Phobos64
    uint32_t key = phobos64_get_key();
    
    if (key == 0) {
        return 0; // No key pressed
    }
    
    // Map Phobos64 key codes to DOOM key codes
    *pressed = (key & 0x80000000) ? 0 : 1; // MSB indicates key release
    key &= 0x7FFFFFFF; // Remove press/release bit
    
    // Simple key mapping (expand this for full keyboard support)
    switch (key) {
        case 0x11: *doomKey = KEY_UPARROW; break;    // W
        case 0x1F: *doomKey = KEY_DOWNARROW; break;  // S  
        case 0x1E: *doomKey = KEY_LEFTARROW; break;  // A
        case 0x20: *doomKey = KEY_RIGHTARROW; break; // D
        case 0x39: *doomKey = KEY_USE; break;        // SPACE
        case 0x1C: *doomKey = KEY_FIRE; break;       // ENTER
        case 0x01: *doomKey = KEY_ESCAPE; break;     // ESC
        default: return 0; // Unsupported key
    }
    
    return 1;
}

void DG_SetWindowTitle(const char* title)
{
    // Phobos64 doesn't have windows, but we could update a status line
    (void)title; // Unused for now
}
EOF

info "✓ Created doomgeneric_phobos64.c"

# Create Phobos64 Makefile for DOOM
cat > Makefile.phobos64 << 'EOF'
# Makefile for DOOM on Phobos64

# Phobos64 cross-compiler (assuming it's in PATH when called from Docker)
CC = x86_64-elf-gcc
CFLAGS = -std=c99 -O2 -Wall -Wextra -ffreestanding -nostdlib
LDFLAGS = -nostdlib -ffreestanding

# Include paths
CFLAGS += -I../../../include

# DOOM source files (from doomgeneric)
DOOM_SOURCES = \
	doomdef.c \
	doomstat.c \
	dstrings.c \
	i_system.c \
	i_sound.c \
	i_music.c \
	m_argv.c \
	m_bbox.c \
	m_cheat.c \
	m_config.c \
	m_controls.c \
	m_fixed.c \
	m_menu.c \
	m_misc.c \
	m_random.c \
	am_map.c \
	d_event.c \
	d_items.c \
	d_iwad.c \
	d_loop.c \
	d_main.c \
	d_mode.c \
	d_net.c \
	f_finale.c \
	f_wipe.c \
	g_game.c \
	hu_lib.c \
	hu_stuff.c \
	info.c \
	i_timer.c \
	memio.c \
	p_ceilng.c \
	p_doors.c \
	p_enemy.c \
	p_floor.c \
	p_inter.c \
	p_lights.c \
	p_map.c \
	p_maputl.c \
	p_mobj.c \
	p_plats.c \
	p_pspr.c \
	p_saveg.c \
	p_setup.c \
	p_sight.c \
	p_spec.c \
	p_switch.c \
	p_telept.c \
	p_tick.c \
	p_user.c \
	r_bsp.c \
	r_data.c \
	r_draw.c \
	r_main.c \
	r_plane.c \
	r_segs.c \
	r_sky.c \
	r_things.c \
	s_sound.c \
	sounds.c \
	st_lib.c \
	st_stuff.c \
	tables.c \
	v_video.c \
	w_checksum.c \
	w_file.c \
	w_main.c \
	w_wad.c \
	wi_stuff.c \
	z_zone.c \
	w_file_stdc.c \
	i_input.c \
	i_video.c \
	doomgeneric.c \
	doomgeneric_phobos64.c

# Object files
OBJS = $(DOOM_SOURCES:.c=.o)

# Default target
doom.elf: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

# Compile rule
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) doom.elf

.PHONY: clean
EOF

info "✓ Created Makefile.phobos64"

# Create README for DOOM setup
cat > README_PHOBOS64.md << 'EOF'
# DOOM for Phobos64

This directory contains the doomgeneric port for Phobos64 OS.

## Building

From the main Phobos64 directory:
```bash
make userspace
```

Or manually:
```bash
cd userspace/doom/doomgeneric
make -f Makefile.phobos64
```

## Requirements

1. DOOM1.WAD file (shareware version available free)
2. Phobos64 syscalls implemented:
   - `phobos64_blit_screen()` - Framebuffer blitting
   - `phobos64_get_ticks()` - System timer
   - `phobos64_sleep()` - Sleep/delay
   - `phobos64_get_key()` - Keyboard input

## Status

- ✓ Platform layer created
- ✓ Build system ready  
- ⏳ Syscalls need implementation (M5)
- ⏳ WAD file loading via VFS (M4)

## Controls (Planned)

- WASD: Movement
- Space: Use/Open doors  
- Enter: Fire
- Esc: Menu
EOF

    info "✓ Created README_PHOBOS64.md"
else
    info "✓ README_PHOBOS64.md already exists (not overwriting)"
fi

# Go back to project root
cd ../../../

log "DOOM setup complete!"
info "To build DOOM later: make userspace (after implementing syscalls)"

# 4. Create a simple third-party status file
log "Creating third-party dependencies status..."
cat > .third-party-status << EOF
# Phobos64 Third-Party Dependencies Status
# Generated by scripts/get-third-party.sh

[Limine]
Status: Ready
Version: v7.x-binary
Files: include/limine.h, limine.conf

[doomgeneric]  
Status: Ready for M5
Version: Latest
Location: userspace/doom/doomgeneric/
Platform: doomgeneric_phobos64.c created

Last Updated: $(date)
EOF

info "✓ Created .third-party-status"

log "All third-party dependencies ready!"
echo
info "Next steps:"
info "  1. Build kernel: make build"
info "  2. Create ISO: make image"  
info "  3. Test boot: make run"
info "  4. DOOM will be ready after M4 (VFS) and M5 (syscalls)"
