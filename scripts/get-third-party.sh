# 1. Create Limine config in root directory
cat > limine.conf << 'EOF'
timeout: 3

:Phobos64 OS
kaslr: no
protocol: limine
kernel_path: boot():/phobos64.elf
resolution: 1024x768
kernel_cmdline: debug
EOF

# 2. Download Limine header
wget https://github.com/limine-bootloader/limine/raw/v7.x-binary/limine.h -O include/limine.h
