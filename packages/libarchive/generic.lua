require("zlib")
require("bzip2")
require("xz")
require("lz4")
require("zstd")
require("libarchive@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libarchive/* .
        # libarchive's archive.h pulls in its private Android syscall
        # wrappers (contrib/android/include/android_lf.h) as soon as
        # __ANDROID__ is defined, but only its NDK build adds that directory,
        # and the CMake build guards the include on a variable the NDK
        # toolchain file here deliberately leaves unset. So add the directory
        # to the include path ourselves, on top of the system's search paths.
        CPPFLAGS="$CPPFLAGS -I$PWD/contrib/android/include"; export CPPFLAGS
        # Static library, with the compression backends this prefix already
        # provides (zlib, bzip2, xz, lz4, zstd) found through its pkg-config
        # path. bsdtar, bsdcp and the tests are host programs.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --without-xml2 --without-expat --disable-bsdtar --disable-bsdcp --disable-bsdcat --disable-tests
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
