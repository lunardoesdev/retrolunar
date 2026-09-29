require("procps@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/procps/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
