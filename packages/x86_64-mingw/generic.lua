-- x86_64-w64-mingw32: Windows cross toolchain (mingw-w64 from distro).
-- Installs go to $OUT (per-package stage dir, merged into
-- $NESTDIR/<sys> on success); $PREFIX is the search path where earlier
-- packages landed. No sysroot, no NDK discovery: tools come from PATH.
-- cmake/meson files live next to this recipe, referenced via $SYSDIR.
return system({
    setup = [[
        # --- toolchain: mingw-w64 gcc + binutils ---
        CC="x86_64-w64-mingw32-gcc"
        CXX="x86_64-w64-mingw32-g++"
        AR="x86_64-w64-mingw32-ar"
        RANLIB="x86_64-w64-mingw32-ranlib"
        LD="x86_64-w64-mingw32-ld"
        STRIP="x86_64-w64-mingw32-strip"
        OBJCOPY="x86_64-w64-mingw32-objcopy"
        READELF="x86_64-w64-mingw32-readelf"
        NM="x86_64-w64-mingw32-nm"
        OBJDUMP="x86_64-w64-mingw32-objdump"
        WINDRES="x86_64-w64-mingw32-windres"
        export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP WINDRES

        # --- search paths: our prefix only, no sysroot ---
        # CPPFLAGS covers the autoconf probes ($CC -E without $CFLAGS).
        CPPFLAGS="-I$PREFIX/include"
        export CPPFLAGS
        CFLAGS="-O2"
        CFLAGS="$CFLAGS -I$PREFIX/include"
        CXXFLAGS="$CFLAGS"
        export CFLAGS CXXFLAGS
        # No -Wl,--undefined-version: that's ELF-only, ld for PE fails.
        LDFLAGS="-L$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
        export LDFLAGS
        # Look up .pc files in our prefix, ignore host ones.
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- build-system defaults: install into $OUT, find in $PREFIX ---
        AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-w64-mingw32 --build=x86_64-pc-linux-gnu"
        AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        # --- target facts for builds that cannot detect their target ---
        # FFmpeg-style configure scripts (libvpx, ffmpeg) are not autoconf
        # and reject --host/--build, and each spells the target its own way:
        # libvpx takes --target=$TARGET_TRIPLET, ffmpeg --arch/--target-os.
        TARGET_TRIPLET="x86_64-w64-mingw32"
        TARGET_ARCH="x86_64"
        TARGET_OS="mingw32"
        export TARGET_TRIPLET TARGET_ARCH TARGET_OS
        CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        # cmake's compiler check links a test program and then runs it. A
        # cross target binary cannot run here, and running one would be
        # emulation, which we never do: link a static library instead.
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
        # cmake runs the make program it finds, and it would find ours:
        # $PREFIX/bin/make is a target binary, so running it would need an
        # emulator. Pin the host make.
        CMAKE_MAKE_PROGRAM="$(command -v make)"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_MAKE_PROGRAM=$CMAKE_MAKE_PROGRAM"
        export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
        MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-mingw.ini"
        MESON_FLAGS="--prefix=$OUT"
        MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
        export MESON_CROSS_FILE MESON_FLAGS

        # --- rust: windows target, same linker family, cross pkg-config ---
        CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
        CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC"
        CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR"
        RUSTFLAGS="-L $PREFIX/lib"
        PKG_CONFIG_ALLOW_CROSS="1"
        CC_x86_64_pc_windows_gnu="$CC"
        CFLAGS_x86_64_pc_windows_gnu="$CFLAGS"
        CXX_x86_64_pc_windows_gnu="$CXX"
        CXXFLAGS_x86_64_pc_windows_gnu="$CXXFLAGS"
        export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
        export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR RUSTFLAGS
        export PKG_CONFIG_ALLOW_CROSS
        export CC_x86_64_pc_windows_gnu CFLAGS_x86_64_pc_windows_gnu
        export CXX_x86_64_pc_windows_gnu CXXFLAGS_x86_64_pc_windows_gnu
    ]],
})
