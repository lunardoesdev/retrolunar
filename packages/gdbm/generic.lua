require("gdbm@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gdbm/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-static \
            --enable-libgdbm-compat
        touch aclocal.m4 configure autoconf.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
