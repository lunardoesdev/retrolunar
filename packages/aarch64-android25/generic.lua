-- aarch64-linux-android25: NDK cross toolchain (from env.sh article).
-- Installs go to $OUT (per-package stage dir, merged into
-- $NESTDIR/<sys> on success); $PREFIX is the search path where earlier
-- packages landed. cmake/meson files live next to this recipe and are
-- referenced via $SYSDIR. Plain VAR=value + grouped `export` lines.
return system({
    recipe_fallbacks = {"android"},
    setup = [[
        # --- NDK discovery: newest version under $ANDROID_HOME/ndk ---
        # Shell glob, no ls: aliases like eza would mangle ls output.
        : "${ANDROID_HOME:?set ANDROID_HOME to an Android SDK with an NDK}"
        _ndk_ver="$(for _ndk_cand in "$ANDROID_HOME/ndk"/*; do
          [ -d "$_ndk_cand" ] || continue
          printf '%s\n' "${_ndk_cand##*/}"
        done | sort -V | tail -1)"
        if [ -z "$_ndk_ver" ]; then
          echo "aarch64-android25: no NDK under $ANDROID_HOME/ndk" >&2
          unset _ndk_ver _ndk_cand
          exit 1
        fi
        NDK="$ANDROID_HOME/ndk/$_ndk_ver"
        unset _ndk_ver _ndk_cand
        export NDK
        TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
        export TOOLCHAIN
        TOOLBIN="$TOOLCHAIN/bin"
        export TOOLBIN
        # $TOOLBIN is deliberately NOT prepended to PATH: a cross toolchain
        # at the front of PATH makes host tools run cross binaries. Every
        # tool is named by full path instead, which is also what cmake and
        # meson need to resolve a compiler that is not in PATH.
        SYSROOT="$TOOLCHAIN/sysroot"
        export SYSROOT

        # --- toolchain: NDK clang wrappers + llvm binutils ---
        # Wrappers already encode the API level (25).
        CC="$TOOLBIN/aarch64-linux-android25-clang"
        CXX="$TOOLBIN/aarch64-linux-android25-clang++"
        AR="$TOOLBIN/llvm-ar"
        RANLIB="$TOOLBIN/llvm-ranlib"
        LD="$TOOLBIN/ld.lld"
        AS="$CC"
        ASM="$CC"
        STRIP="$TOOLBIN/llvm-strip"
        OBJCOPY="$TOOLBIN/llvm-objcopy"
        READELF="$TOOLBIN/llvm-readelf"
        NM="$TOOLBIN/llvm-nm"
        OBJDUMP="$TOOLBIN/llvm-objdump"
        export CC CXX AR RANLIB LD AS ASM STRIP OBJCOPY READELF NM OBJDUMP

        # --- search paths: our prefix first, NDK sysroot second ---
        # CPPFLAGS covers the autoconf probes (e.g. libpng's zlib check
        # and its pnglibconf.h generation, which call $CC -E without
        # $CFLAGS); without $PREFIX first they find the NDK's own
        # ancient zlib.h in the sysroot instead of ours.
        # -isystem $SYSROOT/usr/include must stay C-only: on C++ it
        # reorders libc++ before its own C headers and breaks <cstdint>.
        # libvpx C++ files get the sysroot via --sysroot instead.
        CFLAGS="-O2 -fPIC"
        CFLAGS="$CFLAGS -I$PREFIX/include"
        CFLAGS="$CFLAGS -DANDROID -isystem $SYSROOT/usr/include"
        CXXFLAGS="-O2 -fPIC"
        CXXFLAGS="$CXXFLAGS -I$PREFIX/include"
        CXXFLAGS="$CXXFLAGS -DANDROID"
        # Kept empty on purpose: rust links via RUSTFLAGS below, and a
        # global -L would leak host-style rpath flags into cargo.
        LDFLAGS="-L$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
        # Bionic keeps the math functions in libm; glibc folds them into
        # libc, so a program that calls log2/pow/exp links fine there and
        # fails here. libm is in every Android sysroot, so -lm always costs
        # nothing and saves every package from hitting this.
        LDFLAGS="$LDFLAGS -lm"
        export LDFLAGS
        # Look up .pc files in our prefix, then the NDK sysroot...
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$SYSROOT/usr/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$SYSROOT/usr/share/pkgconfig"
        # ...and ignore every host .pc file outside those dirs.
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- machine identities: build, host, target ---
        # build = the machine that runs the build; host = the machine the
        # artifacts run on (autoconf's --host). FFmpeg-family configure
        # scripts are not autoconf and reject --host/--build, so they read
        # $HOST_ARCH/$HOST_OS and spell them their own way. Nothing here
        # builds a compiler for a further machine: target == host.
        BUILD_TRIPLET="x86_64-pc-linux-gnu"
        HOST_TRIPLET="aarch64-linux-android"
        TARGET_TRIPLET="$HOST_TRIPLET"
        HOST_ARCH="aarch64"
        HOST_OS="android"
        export BUILD_TRIPLET HOST_TRIPLET TARGET_TRIPLET HOST_ARCH HOST_OS

        # --- build-system defaults: install into $OUT, find in $PREFIX ---
        AUTOCONF_CONFIGURE_FLAGS="--host=$HOST_TRIPLET --build=$BUILD_TRIPLET"
        AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        # Autoconf probes link a test program and run it, which cannot work
        # while cross compiling. Bionic defines these as inline functions.
        export ac_cv_func_ffsl=yes
        export gl_cv_func_strcasecmp_works=yes
        CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android25-toolchain.cmake"
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        # cmake's compiler check links a test program and then runs it. A
        # cross target binary cannot run here, and running one would be
        # emulation, which we never do: link a static library instead.
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
        # cmake runs the make program it finds, and it would find ours:
        # $PREFIX/bin/make is an Android binary, so running it would need an
        # emulator. Pin the host make.
        CMAKE_MAKE_PROGRAM="$(command -v make)"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_MAKE_PROGRAM=$CMAKE_MAKE_PROGRAM"
        export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
        MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android25.ini"
        MESON_FLAGS="--prefix=$OUT"
        MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
        export MESON_CROSS_FILE MESON_FLAGS

        # --- rust: target, linker, link path, cross pkg-config ---
        # cc-crate Vars mirror $CC/$CFLAGS for build scripts.
        CARGO_BUILD_TARGET="aarch64-linux-android"
        CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC"
        CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="$AR"
        RUSTFLAGS="-L $PREFIX/lib"
        PKG_CONFIG_ALLOW_CROSS="1"
        CC_aarch64_linux_android="$CC"
        CFLAGS_aarch64_linux_android="$CFLAGS"
        CXX_aarch64_linux_android="$CXX"
        CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
        export CARGO_BUILD_TARGET CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
        export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR RUSTFLAGS
        export PKG_CONFIG_ALLOW_CROSS
        export CC_aarch64_linux_android CFLAGS_aarch64_linux_android
        export CXX_aarch64_linux_android CXXFLAGS_aarch64_linux_android
    ]],
})
