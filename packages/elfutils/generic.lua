require("bzip2")
require("xz")
require("zlib")
require("elfutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/elfutils/* .
        # Debuginfod is not reachable from a build machine; libelf is the part
        # of Elfutils that the rest of the system needs.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 -C libelf install
        mkdir -p $OUT/lib/pkgconfig
        cp config/libelf.pc $OUT/lib/pkgconfig/
    ]]
})
