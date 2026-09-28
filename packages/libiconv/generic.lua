require("libiconv@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libiconv/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --disable-nls
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
