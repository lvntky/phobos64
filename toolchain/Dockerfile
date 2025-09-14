FROM ubuntu:22.04

LABEL maintainer="Levent Kaya"
LABEL description="Cross-compiler toolchain for Phobos64 OS (x86_64-elf)"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    flex \
    libgmp3-dev \
    libmpc-dev \
    libmpfr-dev \
    texinfo \
    libisl-dev \
    wget \
    tar \
    xz-utils \
    curl \
    nasm \
    mtools \
    parted \
    qemu-system-x86 \
    && rm -rf /var/lib/apt/lists/*

# Set up cross-compiler variables
ENV PREFIX="/opt/phobos64-toolchain"
ENV TARGET="x86_64-elf"
ENV PATH="${PREFIX}/bin:${PATH}"
ENV MAKEFLAGS="-j$(nproc)"

# Create toolchain directory
RUN mkdir -p ${PREFIX}

# Download sources
WORKDIR /tmp/toolchain-build
RUN wget -q https://ftp.gnu.org/gnu/binutils/binutils-2.41.tar.xz && \
    wget -q https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz

# Extract sources
RUN tar -xf binutils-2.41.tar.xz && \
    tar -xf gcc-13.2.0.tar.xz

# Build binutils
RUN mkdir -p build-binutils && cd build-binutils && \
    ../binutils-2.41/configure \
        --target=${TARGET} \
        --prefix=${PREFIX} \
        --with-sysroot \
        --disable-nls \
        --disable-werror && \
    make ${MAKEFLAGS} && \
    make install

# Build GCC (cross-compiler)
RUN mkdir -p build-gcc && cd build-gcc && \
    ../gcc-13.2.0/configure \
        --target=${TARGET} \
        --prefix=${PREFIX} \
        --disable-nls \
        --enable-languages=c,c++ \
        --without-headers && \
    make ${MAKEFLAGS} all-gcc && \
    make ${MAKEFLAGS} all-target-libgcc && \
    make install-gcc && \
    make install-target-libgcc

# Clean up build files to reduce image size
RUN rm -rf /tmp/toolchain-build

# Set working directory for development
WORKDIR /workspace

# Create a non-root user for development (optional but recommended)
RUN useradd -m -s /bin/bash phobos64 && \
    chown -R phobos64:phobos64 /workspace

# Display toolchain info when container starts
CMD echo "=== Phobos64 Cross-Compiler Toolchain ===" && \
    echo "Target: ${TARGET}" && \
    echo "Prefix: ${PREFIX}" && \
    echo "GCC Version: $(${TARGET}-gcc --version | head -n1)" && \
    echo "Binutils Version: $(${TARGET}-ld --version | head -n1)" && \
    echo "Available tools:" && \
    ls ${PREFIX}/bin/${TARGET}-* && \
    echo "Ready to build Phobos64!" && \
    /bin/bash
