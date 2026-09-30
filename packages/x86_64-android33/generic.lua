-- x86_64-linux-android33: NDK cross toolchain (from env.sh article).
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
          echo "x86_64-android33: no NDK under $ANDROID_HOME/ndk" >&2
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

        # --- toolchain: NDK clang wrappers + llvm binutils ---
        # Wrappers already encode the API level (33).
        CC="x86_64-linux-android33-clang"
        CXX="x86_64-linux-android33-clang++"
        AR="llvm-ar"
        RANLIB="llvm-ranlib"
        LD="ld.lld"
        STRIP="llvm-strip"
        OBJCOPY="llvm-objcopy"
        READELF="llvm-readelf"
        NM="llvm-nm"
        OBJDUMP="llvm-objdump"
        export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP

        # --- search paths: our prefix first, NDK sysroot second ---
        # CPPFLAGS covers the autoconf probes (e.g. libpng's zlib check
        # and its pnglibconf.h generation, which call $CC -E without
        # $CFLAGS); without $PREFIX first they find the NDK's own
        # ancient zlib.h in the sysroot instead of ours.
        CPPFLAGS="-I$PREFIX/include"
        export CPPFLAGS
        CFLAGS="-O2 -fPIC"
        CFLAGS="$CFLAGS -I$PREFIX/include"
        CFLAGS="$CFLAGS -DANDROID -isystem $SYSROOT/usr/include"
        CXXFLAGS="$CFLAGS"
        export CFLAGS CXXFLAGS
        # Kept empty on purpose: rust links via RUSTFLAGS below, and a
        # global -L would leak host-style rpath flags into cargo.
        LDFLAGS="-L$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
        export LDFLAGS
        # Look up .pc files in our prefix, then the NDK sysroot...
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$SYSROOT/usr/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$SYSROOT/usr/share/pkgconfig"
        # ...and ignore every host .pc file outside those dirs.
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- build-system defaults: install into $OUT, find in $PREFIX ---
        AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-linux-android --build=x86_64-pc-linux-gnu"
        AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        # --- hand-written configure target tuple ---
        # FFmpeg-style configure (libvpx) has no --host/--build and needs an
        # explicit --target. The spelling is libvpx's own, so it lives here
        # and recipes pass it through unchanged.
        TARGET_TRIPLET="x86_64-android-gcc"
        export TARGET_TRIPLET
        # Autoconf probes link a test program and run it, which cannot work
        # while cross compiling. Bionic defines these as inline functions.
        export ac_cv_func_ffsl=yes
        export gl_cv_func_strcasecmp_works=yes
        CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-linux-android33-toolchain.cmake"
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
        MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-android33.ini"
        MESON_FLAGS="--prefix=$OUT"
        MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
        export MESON_CROSS_FILE MESON_FLAGS

        # --- rust: target, linker, link path, cross pkg-config ---
        # cc-crate Vars mirror $CC/$CFLAGS for build scripts.
        CARGO_BUILD_TARGET="x86_64-linux-android"
        CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$CC"
        CARGO_TARGET_X86_64_LINUX_ANDROID_AR="$AR"
        RUSTFLAGS="-L $PREFIX/lib"
        PKG_CONFIG_ALLOW_CROSS="1"
        CC_x86_64_linux_android="$CC"
        CFLAGS_x86_64_linux_android="$CFLAGS"
        CXX_x86_64_linux_android="$CXX"
        CXXFLAGS_x86_64_linux_android="$CXXFLAGS"
        export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER
        export CARGO_TARGET_X86_64_LINUX_ANDROID_AR RUSTFLAGS
        export PKG_CONFIG_ALLOW_CROSS
        export CC_x86_64_linux_android CFLAGS_x86_64_linux_android
        export CXX_x86_64_linux_android CXXFLAGS_x86_64_linux_android
    ]],
})
