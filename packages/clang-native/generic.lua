return system({
    env = {
        PREFIX="$NESTDIR/clang-native",
        CC = "clang",
        CXX = "clang++",
        AR = "llvm-ar",
        RANLIB = "llvm-ranlib",
        LD = "ld.lld",
        AS = "$CC",
        STRIP = "llvm-strip",
        OBJCOPY = "llvm-objcopy",
        READELF = "llvm-readelf",
        OBJDUMP = "llvm-objdump",

        CPPFLAGS = "-I$PREFIX/include",
        CFLAGS = "-O2 -fPIC",
        CXXFLAGS = "-O2 -fPIC",
        LDFLAGS = "-L$PREFIX/lib  -Wl,-rpath-link,$PREFIX/lib -Wl,--undefined-version",

        PKG_CONFIG_LIBDIR = "$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig",
        PKG_CONFIG_PATH = "",

        AUTOCONF_CONFIGURE_FLAGS = "--prefix=$PREFIX",

        CMAKE_PREFIX_PATH = "$PREFIX",
        CMAKE_FLAGS = "-DCMAKE_INSTALL_PREFIX=$PREFIX"
    }
})
