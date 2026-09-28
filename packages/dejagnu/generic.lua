require("tcl")
require("dejagnu@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/dejagnu/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
