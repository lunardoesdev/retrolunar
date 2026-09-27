return system({
    setup = [[
        CC="clang"
        export CC
        CXX="clang++"
        export CXX
        AR="llvm-ar"
        export AR
        RANLIB="llvm-ranlib"
        export RANLIB
        LD="ld.lld"
        export LD
        AS="$CC"
        export AS
        STRIP="llvm-strip"
        export STRIP
        OBJCOPY="llvm-objcopy"
        export OBJCOPY
        READELF="llvm-readelf"
        export READELF
        OBJDUMP="llvm-objdump"
        export OBJDUMP
        CPPFLAGS="-I$PREFIX/include"
        export CPPFLAGS
        CFLAGS="-O2 -fPIC"
        export CFLAGS
        CXXFLAGS="-O2 -fPIC"
        export CXXFLAGS
        LDFLAGS="-L$PREFIX/lib  -Wl,-rpath-link,$PREFIX/lib -Wl,--undefined-version"
        export LDFLAGS
        PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
        export PKG_CONFIG_LIBDIR
        PKG_CONFIG_PATH=""
        export PKG_CONFIG_PATH
        AUTOCONF_CONFIGURE_FLAGS="--prefix=$OUT"
        export AUTOCONF_CONFIGURE_FLAGS
        CMAKE_PREFIX_PATH="$PREFIX"
        export CMAKE_PREFIX_PATH
        CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
        export CMAKE_FLAGS
    ]],
})
