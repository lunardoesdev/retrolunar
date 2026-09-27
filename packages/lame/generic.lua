require("lame@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lame/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --disable-frontend --disable-gtktest --disable-nasm
        touch aclocal.m4 configure config.h.in
        make -j$(nproc 2>/dev/null || echo 4)
        make -C libmp3lame install
        make -C include install
    ]]
})
