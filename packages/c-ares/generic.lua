require("c-ares@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/c-ares/* .
        # Static library, headers and the pkg-config file. The two sample
        # tools (adig, ahost) are noinst_PROGRAMS: they are compiled as
        # target programs but never installed, and no switch stops the
        # compile. --disable-tests is the real cut, because the test suite
        # wants a live network the build machine should not depend on.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-tests
        touch aclocal.m4 configure src/lib/ares_config.h.in include/ares_build.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
