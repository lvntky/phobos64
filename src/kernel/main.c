// src/kernel/main.c - Phobos64 Kernel Entry Point

#include <limine.h>
#include <stddef.h>
#include <stdint.h>

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
__attribute__((used,
	       section(".requests"))) static volatile LIMINE_BASE_REVISION(2);

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent, _and_ they should be accessed at least
// once or marked as used with the "used" attribute as done here.

__attribute__((
	used,
	section(".requests"))) static volatile struct limine_framebuffer_request
	framebuffer_request = { .id = LIMINE_FRAMEBUFFER_REQUEST,
				.revision = 0 };

__attribute__((
	used,
	section(".requests"))) static volatile struct limine_memmap_request
	memmap_request = { .id = LIMINE_MEMMAP_REQUEST, .revision = 0 };

__attribute__((used,
	       section(".requests"))) static volatile struct limine_hhdm_request
	hhdm_request = { .id = LIMINE_HHDM_REQUEST, .revision = 0 };

__attribute__((
	used,
	section(".requests"))) static volatile struct limine_kernel_address_request
	kernel_address_request = { .id = LIMINE_KERNEL_ADDRESS_REQUEST,
				   .revision = 0 };

// Halt function for when we're done
static void done(void)
{
	for (;;) {
		__asm__("hlt");
	}
}

// Simple framebuffer pixel plotting
static void plot_pixel(struct limine_framebuffer *framebuffer, uint32_t x,
		       uint32_t y, uint32_t color)
{
	if (x >= framebuffer->width || y >= framebuffer->height) {
		return;
	}

	uint32_t *fb_ptr = (uint32_t *)framebuffer->address;
	fb_ptr[y * framebuffer->width + x] = color;
}

// Draw a simple pattern to test framebuffer
static void test_framebuffer(struct limine_framebuffer *framebuffer)
{
	// Clear screen to black
	for (uint64_t i = 0; i < framebuffer->height; i++) {
		for (uint64_t j = 0; j < framebuffer->width; j++) {
			plot_pixel(framebuffer, j, i, 0x000000);
		}
	}

	// Draw Phobos64 logo pattern (simple rectangles)
	uint32_t colors[] = { 0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00 };

	for (int i = 0; i < 4; i++) {
		uint32_t start_x = 50 + i * 100;
		uint32_t start_y = 50;

		for (uint32_t y = start_y; y < start_y + 80; y++) {
			for (uint32_t x = start_x; x < start_x + 80; x++) {
				plot_pixel(framebuffer, x, y, colors[i]);
			}
		}
	}

	// Draw border
	for (uint32_t x = 0; x < framebuffer->width; x++) {
		plot_pixel(framebuffer, x, 0, 0xFFFFFF);
		plot_pixel(framebuffer, x, framebuffer->height - 1, 0xFFFFFF);
	}
	for (uint32_t y = 0; y < framebuffer->height; y++) {
		plot_pixel(framebuffer, 0, y, 0xFFFFFF);
		plot_pixel(framebuffer, framebuffer->width - 1, y, 0xFFFFFF);
	}
}

// The following will be our kernel's entry point.
void _start(void)
{
	// Ensure the bootloader actually understands our base revision (see spec).
	if (LIMINE_BASE_REVISION_SUPPORTED == false) {
		done();
	}

	// Check if framebuffer is available
	if (framebuffer_request.response == NULL ||
	    framebuffer_request.response->framebuffer_count < 1) {
		done();
	}

	// Get the first framebuffer
	struct limine_framebuffer *framebuffer =
		framebuffer_request.response->framebuffers[0];

	// Test the framebuffer
	test_framebuffer(framebuffer);

	// Print memory map info (will need serial output later)
	if (memmap_request.response != NULL) {
		struct limine_memmap_response *memmap = memmap_request.response;

		// TODO: Parse memory map entries
		// for (uint64_t i = 0; i < memmap->entry_count; i++) {
		//     struct limine_memmap_entry *entry = memmap->entries[i];
		//     // Process memory regions
		// }
	}

	// Print kernel load address info
	if (kernel_address_request.response != NULL) {
		// TODO: Use kernel physical/virtual addresses for memory management
		// uint64_t phys_base = kernel_address_request.response->physical_base;
		// uint64_t virt_base = kernel_address_request.response->virtual_base;
	}

	// Print HHDM offset
	if (hhdm_request.response != NULL) {
		// TODO: Use higher half direct map for easy physical memory access
		// uint64_t hhdm_offset = hhdm_request.response->offset;
	}

	// We're done, just hang...
	done();
}
