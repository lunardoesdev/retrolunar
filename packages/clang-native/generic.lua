-- host-linux via local clang. Installs go to $OUT (per-package stage
-- dir, merged into $NESTDIR/<sys> on success); $PREFIX is the search
-- path where earlier packages landed. Plain VAR=value + `export VAR`
-- lines so the generated script stays readable without emitter magic.
return system({
    setup = [[
        # --- toolchain: local clang + llvm binutils ---
        CC="clang"
        CXX="clang++"
        AR="llvm-ar"
        RANLIB="llvm-ranlib"
        LD="ld.lld"
        AS="$CC"
        STRIP="llvm-strip"
        OBJCOPY="llvm-objcopy"
        READELF="llvm-readelf"
        OBJDUMP="llvm-objdump"
        export CC CXX AR RANLIB LD AS STRIP OBJCOPY READELF OBJDUMP

        # --- search paths: headers, libraries, pkg-config ---
        # $PREFIX points at this system's nest dir, where deps landed.
        # CPPFLAGS/LDFLAGS cover the autoconf probes (e.g. libpng's
        # zlib check); plain CFLAGS stay clean for direct $CC users.
        CPPFLAGS="-I$PREFIX/include"
        CFLAGS="-O2 -fPIC"
        CFLAGS="$CFLAGS $CPPFLAGS"
        CXXFLAGS="-O2 -fPIC"
        CXXFLAGS="$CXXFLAGS $CPPFLAGS"
        LDFLAGS="-L$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,--undefined-version"
        export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
        # Ignore host .pc files: only ours count.
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- machine identities: build, host, target ---
        # A native build runs on the same machine it targets, so build, host
        # and target are one triplet. FFmpeg-family configure scripts are not
        # autoconf and reject --host/--build, so they read $HOST_ARCH/
        # $HOST_OS and spell them their own way.
        BUILD_TRIPLET="x86_64-pc-linux-gnu"
        HOST_TRIPLET="$BUILD_TRIPLET"
        TARGET_TRIPLET="$HOST_TRIPLET"
        HOST_ARCH="x86_64"
        HOST_OS="linux"
        export BUILD_TRIPLET HOST_TRIPLET TARGET_TRIPLET HOST_ARCH HOST_OS

        # --- build-system defaults: install into $OUT ---
        AUTOCONF_CONFIGURE_FLAGS="--build=$BUILD_TRIPLET --prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        # MESON_FLAGS was missing here entirely, which is a silent-failure
        # defect rather than a cosmetic gap: meson with no --prefix records
        # prefix=/usr/local, so a meson build compiles happily, "installs",
        # writes nothing into $OUT, and reports no error. The package then
        # appears to build and produces no artifact at all.
        #
        # --prefix only. Unlike the cross systems there is no cross-file to
        # pass, because meson takes the native toolchain from the environment
        # ($CC, $CXX, $AR and friends are all exported above), and no policy
        # floor is needed because this is not cmake. Serial builds come from
        # the recipes' own `meson compile --jobs 1`, not from here.
        MESON_FLAGS="--prefix=$OUT"
        export CMAKE_PREFIX_PATH CMAKE_FLAGS MESON_FLAGS
    ]],
})
