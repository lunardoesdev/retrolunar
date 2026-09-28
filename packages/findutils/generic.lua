require("findutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/findutils/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --localstatedir="$OUT/var/lib/locate"
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
