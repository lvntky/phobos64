# phobos64

**phobos64** is a hobbyist **64-bit graphical operating system**, designed from scratch to boot on x86-64 hardware via UEFI.  
Its core MVP goal: **boot → draw pixels → run one user program (DOOM)**.  

This project is the spiritual sibling of [ArtilleryOS](https://github.com/lvntky/ArtilleryOS),  
sharing the same focus but way more experimental operating system design than ArtilleryOS.

---

## Features (MVP Roadmap)
- **UEFI Boot** with Limine
- **Long Mode** (x86-64) setup with paging, GDT/IDT
- **Framebuffer Driver** via UEFI GOP (putpixel, blit, text with PSF font)
- **Input Drivers**: PS/2 keyboard (mouse optional)
- **Initrd + VFS**: simple read-only filesystem in memory
- **Userspace ELF Loader**: one process, ring3 execution
- **Syscall ABI**: framebuffer blit, input, ticks/sleep, file read
- **Demo App**: bitmap console & toy GUI
- **DOOM Port**: powered by [doomgeneric](https://github.com/ozkl/doomgeneric)

---

## Milestones
- [ ] **M0**: Toolchain & Boot Skeleton  
- [ ] **M1**: Long Mode & Memory Management  
- [ ] **M2**: Framebuffer Graphics & On-Screen Logging  
- [ ] **M3**: Keyboard Input + Cursor Rendering  
- [ ] **M4**: Initrd & Read-Only VFS  
- [ ] **M5**: User ELF Support + Syscalls  
- [ ] **M5.2**: Run DOOM as the first "real" program 🎮  

---

## Building & Running
Requirements:
- Linux host
- `qemu-system-x86_64`
- `nasm`, `x86_64-elf-gcc/clang`, `ld`, `objcopy`
- `python3` (for initrd tools)

Build & run:
```bash
./tools/image.sh
./tools/run_qemu.sh
```

---

## Related Projects
- [ArtilleryOS](https://github.com/lvntky/ArtilleryOS) another experimental OS project focused on low-level systems.
- phobos64 builds upon lessons learned in ArtilleryOS, extending into 64-bit graphical and userspace territory.

---

## License
Phobos64 is released under the MIT license.
Doom integration uses GPLv2 sources from doomgeneric.
Game data (`doom1.wad`) is not included; users must provide their own copy (the shareware WAD is supported).
