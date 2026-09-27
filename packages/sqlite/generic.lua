require("sqlite@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/sqlite/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
