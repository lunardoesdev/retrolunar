require("ncurses@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ncurses/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --with-shared \
            --without-debug \
            --without-normal \
            --with-cxx-shared \
            --enable-pc-files \
            --with-pkg-config-libdir=$OUT/lib/pkgconfig \
            --disable-stripping
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
        # Preserve traditional link names expected by consumers.
        ln -sf libncursesw.so $OUT/lib/libcurses.so
        ln -sf libncursesw.so $OUT/lib/libncurses.so
        ln -sf libformw.so $OUT/lib/libform.so
        ln -sf libmenuw.so $OUT/lib/libmenu.so
        ln -sf libpanelw.so $OUT/lib/libpanel.so
        ln -sf ncursesw.pc $OUT/lib/pkgconfig/ncurses.pc
        ln -sf formw.pc $OUT/lib/pkgconfig/form.pc
        ln -sf menuw.pc $OUT/lib/pkgconfig/menu.pc
        ln -sf panelw.pc $OUT/lib/pkgconfig/panel.pc
    ]]
})
