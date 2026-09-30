require("less@source")
require("ncurses")

return recipe({
    build = [[
        cp -r $NESTDIR/source/less/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure defines.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
