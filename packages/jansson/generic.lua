require("jansson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/jansson/* .
        # Autotools build, static library only: a target prefix wants the
        # archive and the header, and the tests and docs are host-side work.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
