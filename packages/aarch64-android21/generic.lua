-- aarch64-linux-android21: NDK cross toolchain (from env.sh article).
-- PREFIX/OUT contract: PREFIX is the search path (nest prefix),
-- OUT is the per-package stage dir. Install flags point at $OUT;
-- search flags at $PREFIX. setup locates
-- the NDK, puts its wrappers on PATH, then exports the toolchain
-- (plain names, found via PATH); cmake/meson files live next to this
-- recipe and are referenced via $SYSDIR.
return system({
    setup = [[
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
        CC="aarch64-linux-android21-clang"
        export CC
        CXX="aarch64-linux-android21-clang++"
        export CXX
        AR="llvm-ar"
        export AR
        RANLIB="llvm-ranlib"
        export RANLIB
        LD="ld.lld"
        export LD
        STRIP="llvm-strip"
        export STRIP
        OBJCOPY="llvm-objcopy"
        export OBJCOPY
        READELF="llvm-readelf"
        export READELF
        NM="llvm-nm"
        export NM
        OBJDUMP="llvm-objdump"
        export OBJDUMP
        CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
        export CFLAGS
        CXXFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
        export CXXFLAGS
        LDFLAGS=""
        export LDFLAGS
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
        export PKG_CONFIG_LIBDIR
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_PATH
        AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android21-toolchain.cmake"
        export CMAKE_TOOLCHAIN_FILE
        CMAKE_PREFIX_PATH="$PREFIX"
        export CMAKE_PREFIX_PATH
        CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
        export CMAKE_FLAGS
        MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android21.ini"
        export MESON_CROSS_FILE
        MESON_FLAGS="--prefix=$OUT --cross-file $SYSDIR/crossfile-aarch64-android21.ini"
        export MESON_FLAGS
        CARGO_BUILD_TARGET="aarch64-linux-android"
        export CARGO_BUILD_TARGET
        CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android21-clang"
        export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
        CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="llvm-ar"
        export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR
        RUSTFLAGS="-L $PREFIX/lib"
        export RUSTFLAGS
        PKG_CONFIG_ALLOW_CROSS="1"
        export PKG_CONFIG_ALLOW_CROSS
        CC_aarch64_linux_android="$CC"
        export CC_aarch64_linux_android
        CFLAGS_aarch64_linux_android="$CFLAGS"
        export CFLAGS_aarch64_linux_android
        CXX_aarch64_linux_android="$CXX"
        export CXX_aarch64_linux_android
        CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
        export CXXFLAGS_aarch64_linux_android
    ]],
})
