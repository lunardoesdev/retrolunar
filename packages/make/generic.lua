require("make@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/make/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
