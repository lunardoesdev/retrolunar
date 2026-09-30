require("libyaml@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libyaml/* .
        # Static library, header and pkg-config file. The reference parser
        # and the hpricot test tool are host programs and stay off; so does
        # the optional uchardet encoding probe, which the generic build would
        # otherwise try to compile.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-python-bindings
        touch aclocal.m4 configure include/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
