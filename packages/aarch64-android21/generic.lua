-- aarch64-linux-android21: NDK cross toolchain (from env.sh article).
-- PREFIX/OUT contract: PREFIX is the search path (nest prefix),
-- OUT is the per-package stage dir. Install flags point at $OUT,
-- search flags at $PREFIX. preenv locates the NDK and puts its
-- wrappers on PATH (plain names: CC coexist with setup); cmake/meson
-- files live next to this recipe and are referenced via $SYSDIR.
return system({
    env = {
        CC = "aarch64-linux-android21-clang",
        CXX = "aarch64-linux-android21-clang++",
        AR = "llvm-ar",
        RANLIB = "llvm-ranlib",
        LD = "ld.lld",
        STRIP = "llvm-strip",
        OBJCOPY = "llvm-objcopy",
        READELF = "llvm-readelf",
        NM = "llvm-nm",
        OBJDUMP = "llvm-objdump",

        SYSROOT = "$TOOLCHAIN/sysroot",

        CFLAGS = "-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include",
        CXXFLAGS = "-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include",
        LDFLAGS = "",

        PKG_CONFIG_LIBDIR = "$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig",
        PKG_CONFIG_PATH = "",

        AUTOCONF_CONFIGURE_FLAGS = "--host=aarch64-linux-android --prefix=$PREFIX",

        CMAKE_TOOLCHAIN_FILE = "$SYSDIR/aarch64-linux-android21-toolchain.cmake",
        CMAKE_PREFIX_PATH = "$PREFIX",
        CMAKE_FLAGS = "-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_PREFIX_PATH=$PREFIX",

        MESON_CROSS_FILE = "$SYSDIR/crossfile-aarch64-android21.ini",
        MESON_FLAGS = "--prefix=$PREFIX --cross-file $SYSDIR/crossfile-aarch64-android21.ini",
        CARGO_BUILD_TARGET = "aarch64-linux-android",
        CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = "aarch64-linux-android21-clang",
        CARGO_TARGET_AARCH64_LINUX_ANDROID_AR = "llvm-ar",
        RUSTFLAGS = "-L $PREFIX/lib",
        PKG_CONFIG_ALLOW_CROSS = "1",
    },
    preenv = [[
        : "${ANDROID_HOME:?set ANDROID_HOME to an Android SDK with an NDK}"
        _ndk_ver="$(for _ndk_cand in "$ANDROID_HOME/ndk"/*; do
          [ -d "$_ndk_cand" ] || continue
          printf '%s\n' "${_ndk_cand##*/}"
        done | sort -V | tail -1)"
        if [ -z "$_ndk_ver" ]; then
          echo "aarch64-android21: no NDK under $ANDROID_HOME/ndk" >&2
          unset _ndk_ver _ndk_cand
          exit 1
        fi
        NDK="$ANDROID_HOME/ndk/$_ndk_ver"
        unset _ndk_ver _ndk_cand
        export NDK
        TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
        export TOOLCHAIN
        PATH="$TOOLCHAIN/bin:$PATH"
        export PATH
        SYSROOT="$TOOLCHAIN/sysroot"
        export SYSROOT
    ]],
})
