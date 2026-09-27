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
        CPPFLAGS="-I$PREFIX/include"
        CFLAGS="-O2 -fPIC"
        CXXFLAGS="-O2 -fPIC"
        LDFLAGS="-L$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
        LDFLAGS="$LDFLAGS -Wl,--undefined-version"
        export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
        # Ignore host .pc files: only ours count.
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

        # --- build-system defaults: install into $OUT ---
        AUTOCONF_CONFIGURE_FLAGS="--prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        CMAKE_PREFIX_PATH="$PREFIX"
        CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$OUT"
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
        export CMAKE_PREFIX_PATH CMAKE_FLAGS
    ]],
})
