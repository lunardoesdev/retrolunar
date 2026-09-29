require("grep@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/grep/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
