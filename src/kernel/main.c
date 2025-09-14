// src/kernel/main.c - Phobos64 Kernel Entry Point

#include <limine.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
__attribute__((used, section(".requests")))
static volatile LIMINE_BASE_REVISION(2);

// Limine requests (mark as used & place in .requests so the linker keeps them)
__attribute__((used, section(".requests")))
static volatile struct limine_framebuffer_request framebuffer_request = {
    .id = LIMINE_FRAMEBUFFER_REQUEST, .revision = 0};

__attribute__((used, section(".requests")))
static volatile struct limine_memmap_request memmap_request = {
    .id = LIMINE_MEMMAP_REQUEST, .revision = 0};

__attribute__((used, section(".requests")))
static volatile struct limine_hhdm_request hhdm_request = {
    .id = LIMINE_HHDM_REQUEST, .revision = 0};

__attribute__((used, section(".requests")))
static volatile struct limine_kernel_address_request kernel_address_request = {
    .id = LIMINE_KERNEL_ADDRESS_REQUEST, .revision = 0};

// Halt function for when we're done
static void done(void) {
    for (;;) {
        __asm__ __volatile__("hlt");
    }
}

// Safer framebuffer pixel plotting (respects pitch)
static inline void plot_pixel(struct limine_framebuffer *fb,
                              uint32_t x, uint32_t y, uint32_t color) {
    if (!fb) return;
    if (x >= fb->width || y >= fb->height) return;

    // pitch is in bytes; convert to u32-pixels by dividing by 4 (assuming 32bpp)
    uint8_t  *base = (uint8_t *)fb->address;
    uint32_t *row  = (uint32_t *)(base + (uint64_t)y * fb->pitch);
    row[x] = color;
}

// Draw a simple pattern to test framebuffer
static void test_framebuffer(struct limine_framebuffer *fb) {
    // Clear screen to black
    for (uint32_t y = 0; y < fb->height; y++) {
        for (uint32_t x = 0; x < fb->width; x++) {
            plot_pixel(fb, x, y, 0x000000);
        }
    }

    // Draw Phobos64 logo pattern (simple rectangles)
    const uint32_t colors[] = {0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00};
    for (int i = 0; i < 4; i++) {
        uint32_t start_x = 50u + (uint32_t)i * 100u;
        uint32_t start_y = 50u;

        for (uint32_t y = start_y; y < start_y + 80u && y < fb->height; y++) {
            for (uint32_t x = start_x; x < start_x + 80u && x < fb->width; x++) {
                plot_pixel(fb, x, y, colors[i]);
            }
        }
    }

    // Draw border
    for (uint32_t x = 0; x < fb->width; x++) {
        plot_pixel(fb, x, 0, 0xFFFFFF);
        plot_pixel(fb, x, fb->height - 1, 0xFFFFFF);
    }
    for (uint32_t y = 0; y < fb->height; y++) {
        plot_pixel(fb, 0, y, 0xFFFFFF);
        plot_pixel(fb, fb->width - 1, y, 0xFFFFFF);
    }
}

// Kernel entry point
void _start(void) {
    // Ensure the bootloader understands our base revision (see spec).
    if (LIMINE_BASE_REVISION_SUPPORTED == false) {
        done();
    }

    // Check if framebuffer is available
    if (framebuffer_request.response == NULL ||
        framebuffer_request.response->framebuffer_count < 1) {
        done();
    }

    // Get the first framebuffer
    struct limine_framebuffer *fb = framebuffer_request.response->framebuffers[0];

    // Test the framebuffer
    test_framebuffer(fb);

    // Access (or silence) other request responses for now
    if (memmap_request.response != NULL) {
        struct limine_memmap_response *memmap = memmap_request.response;
        (void)memmap; // TODO: parse and use entries
    }

    if (kernel_address_request.response != NULL) {
        // uint64_t phys_base = kernel_address_request.response->physical_base;
        // uint64_t virt_base = kernel_address_request.response->virtual_base;
        // TODO: use for paging/relocations
    }

    if (hhdm_request.response != NULL) {
        // uint64_t hhdm_offset = hhdm_request.response->offset;
        // TODO: use for direct-physical mapping
    }

    // We're done, hang...
    done();
}
