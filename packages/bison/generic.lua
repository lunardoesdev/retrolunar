require("gperf@native")
require("bison@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bison/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure lib/config.in.h
        find . -name 'Makefile.in' | xargs touch
        # Bison generates build-time tables with a native gperf executable.
        make -j1
        make install
    ]]
})
