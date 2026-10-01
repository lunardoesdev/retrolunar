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
        # The Windows import libraries are NOT in $LDFLAGS, and that is a
        # deliberate result of measuring where they have to land.
        #
        # cmake seeds CMAKE_EXE_LINKER_FLAGS from $LDFLAGS on its own
        # (CMakeCommonLanguageInclude.cmake:9 appends "$ENV{LDFLAGS}" to
        # CMAKE_EXE_LINKER_FLAGS_INIT), so putting them there does put them
        # on the link line -- but BEFORE the archives that reference them.
        # i2pd links its static libs through a response file, so libcrypto.a
        # is scanned after every linker flag, and ld does not revisit an
        # archive it already passed. Measured, with the objects from a real
        # failed build:
        #   ... -lcrypt32 -lole32 -loleaut32 -luuid -lgdi32 \
        #       -Wl,--whole-archive objects.a ... @linkLibs.rsp
        #     -> undefined reference to `__imp_CertFindCertificateInStore'
        # and the same flags moved to the END of the identical link line:
        #     -> i2pd.exe, clean link.
        #
        # CMAKE_REQUIRED_LIBRARIES is the variable i2pd itself forwards to
        # the final link (build/CMakeLists.txt:409), so it lands after
        # linkLibs.rsp, which is the position that resolves.
        #
        # -lcrypt32 is the load-bearing one: OpenSSL's mingw build reaches
        # the Windows certificate store, so libcrypto.a itself carries the
        # __imp_CertFindCertificateInStore reference. -lole32/-loleaut32/
        # -luuid are what Win32/COM consumers need (CoCreateInstance,
        # CoUninitialize, the IID_/CLSID_ constants); -lgdi32 is parity with
        # upstream's Makefile.mingw:44-52. Upstream's cmake only appends
        # crypt32 for MSVC (build/CMakeLists.txt:378-381), so a mingw build
        # has to get these from the system.
        export LDFLAGS
        # Look up .pc files in our prefix, ignore host ones.
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- machine identities: build, host, target ---
        # build = the machine that runs the build; host = the machine the
        # artifacts run on (autoconf's --host). FFmpeg-family configure
        # scripts are not autoconf and reject --host/--build, so they read
        # $HOST_ARCH/$HOST_OS and spell them their own way. Nothing here
        # builds a compiler for a further machine: target == host.
        BUILD_TRIPLET="x86_64-pc-linux-gnu"
        HOST_TRIPLET="x86_64-w64-mingw32"
        TARGET_TRIPLET="$HOST_TRIPLET"
        HOST_ARCH="x86_64"
        HOST_OS="mingw32"
        export BUILD_TRIPLET HOST_TRIPLET TARGET_TRIPLET HOST_ARCH HOST_OS

        # --- build-system defaults: install into $OUT, find in $PREFIX ---
        AUTOCONF_CONFIGURE_FLAGS="--host=$HOST_TRIPLET --build=$BUILD_TRIPLET"
        AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        # The Windows import libraries go here, at the END of the link line,
        # not in $LDFLAGS. See the comment on $LDFLAGS above for the
        # measurement: cmake seeds CMAKE_EXE_LINKER_FLAGS from $LDFLAGS, which
        # places those flags BEFORE the archives that reference them, and ld
        # does not revisit an archive it has already scanned.
        #
        # CMAKE_REQUIRED_LIBRARIES is the variable i2pd forwards to its final
        # link (build/CMakeLists.txt:409), so it lands after linkLibs.rsp.
        # The name is unfortunate -- "required" reads like a test-only thing,
        # and for most projects it is indeed used by try_compile -- but the
        # project already puts it on the real link line, which is what we
        # need. It is also harmless elsewhere: a project that only uses it in
        # try_compile links exactly as before.
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_REQUIRED_LIBRARIES=crypt32\;ole32\;oleaut32\;uuid\;gdi32"
        # cmake's compiler check links a test program and then runs it. A
        # cross target binary cannot run here, and running one would be
        # emulation, which we never do: link a static library instead.
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
        # cmake 4.x refuses any project whose minimum policy is below 3.5,
        # and most of these projects are older than cmake itself. Give them
        # a floor instead of editing their CMakeLists.txt.
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        # cmake runs the make program it finds, and it would find ours:
        # $PREFIX/bin/make is a target binary, so running it would need an
        # emulator. Pin the host make.
        CMAKE_MAKE_PROGRAM="$(command -v make)"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_MAKE_PROGRAM=$CMAKE_MAKE_PROGRAM"
        # ZLIB_ROOT is a search-path hint (FindZLIB.cmake:140-143 searches it
        # first), and it is ALSO read directly by projects: i2pd does
        # `link_directories(${ZLIB_ROOT}/lib)` at build/CMakeLists.txt:314.
        # Left unset, that expands to the literal path /lib, and on this
        # build host /lib is a symlink to /usr/lib -- the HOST's library
        # directory. So the target link line grew `-L/lib`, and every
        # `-lpthread` after it resolved to glibc's libpthread.a, which on
        # this host is an 8-byte empty archive (`!<arch>\n`, verified with
        # od). mingw's real winpthreads archive at
        # /usr/x86_64-w64-mingw32/lib/libpthread.a was never reached and the
        # link died on `undefined reference to pthread_self' and every other
        # winpthreads symbol. A host library directory on a target link line
        # is never what anyone meant; pointing the variable at $PREFIX is.
        CMAKE_FLAGS="$CMAKE_FLAGS -DZLIB_ROOT=$PREFIX"
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
