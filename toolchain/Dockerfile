FROM ubuntu:22.04

LABEL maintainer="Phobos64 Developer"
LABEL description="Cross-compiler toolchain for Phobos64 OS (x86_64-elf)"

ENV DEBIAN_FRONTEND=noninteractive
# Cross-compiler variables
ENV PREFIX="/opt/phobos64-toolchain"
ENV TARGET="x86_64-elf"
ENV PATH="${PREFIX}/bin:${PATH}"

# Make the build output deterministic & verbose
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 1) Build deps (added: zlib1g-dev, libexpat1-dev, python3, pkg-config, file, ca-certificates, gawk)
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    flex \
    gawk \
    libgmp3-dev \
    libmpc-dev \
    libmpfr-dev \
    libisl-dev \
    texinfo \
    zlib1g-dev \
    libexpat1-dev \
    pkg-config \
    python3 \
    file \
    ca-certificates \
    wget \
    curl \
    tar \
    xz-utils \
    nasm \
    mtools \
    parted \
    qemu-system-x86 \
  && rm -rf /var/lib/apt/lists/*

# 2) Sources
WORKDIR /tmp/toolchain-build
RUN set -euxo pipefail && \
    wget -q https://ftp.gnu.org/gnu/binutils/binutils-2.41.tar.xz && \
    wget -q https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz && \
    tar -xf binutils-2.41.tar.xz && \
    tar -xf gcc-13.2.0.tar.xz

# 3) Build & install binutils
RUN set -euxo pipefail && \
    mkdir -p "${PREFIX}" && \
    mkdir -p build-binutils && cd build-binutils && \
    ../binutils-2.41/configure \
        --target="${TARGET}" \
        --prefix="${PREFIX}" \
        --with-sysroot \
        --with-zlib \
        --with-expat \
        --disable-nls \
        --disable-werror && \
    make -j"$(nproc)" && \
    make install

# 4) Build & install GCC stage1 (C + libgcc)
RUN set -euxo pipefail && \
    mkdir -p build-gcc && cd build-gcc && \
    ../gcc-13.2.0/configure \
        --target="${TARGET}" \
        --prefix="${PREFIX}" \
        --disable-nls \
        --enable-languages=c,c++ \
        --without-headers \
        --disable-libssp \
        --disable-shared \
        --disable-multilib && \
    make -j"$(nproc)" all-gcc && \
    make -j"$(nproc)" all-target-libgcc && \
    make install-gcc && \
    make install-target-libgcc

# 5) Cleanup
RUN rm -rf /tmp/toolchain-build

# 6) Dev user & workspace
WORKDIR /workspace
RUN useradd -m -s /bin/bash phobos64 && chown -R phobos64:phobos64 /workspace

# 7) Nice banner via a small entrypoint script; JSON-form CMD fixes the warning
RUN cat >/usr/local/bin/phobos64-banner <<'SH' && chmod +x /usr/local/bin/phobos64-banner
#!/usr/bin/env bash
echo "=== Phobos64 Cross-Compiler Toolchain ==="
echo "Target: ${TARGET}"
echo "Prefix: ${PREFIX}"
if command -v ${TARGET}-gcc >/dev/null 2>&1; then
  echo "GCC:    $(${TARGET}-gcc --version | head -n1)"
fi
if command -v ${TARGET}-ld >/dev/null 2>&1; then
  echo "LD:     $(${TARGET}-ld --version | head -n1)"
fi
echo "Tools in ${PREFIX}/bin:"
ls -1 ${PREFIX}/bin/${TARGET}-* 2>/dev/null || true
echo "Ready to build Phobos64!"
SH

ENTRYPOINT ["/usr/local/bin/phobos64-banner"]
CMD ["/bin/bash"]
