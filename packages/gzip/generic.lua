require("gzip@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gzip/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure lib/config.hin
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
