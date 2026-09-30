require("c-ares@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/c-ares/* .
        # Static library, headers and the pkg-config file. The tools
        # (adig, ahost, aadd) are host programs and stay off; the tests need
        # a network the build machine should not depend on.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-tests
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
