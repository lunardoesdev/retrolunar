require("ncurses@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ncurses/* .
        # --with-shared (with no static equivalent) is a deliberate departure
        # from this prefix's static convention: ncurses' tic/infocmp and the
        # wide-character ABI are awkward to build static-only, and
        # --without-normal below means the tree carries only the wide-char
        # libraries. The .pc files still describe them.
        # --without-normal: build only the wide-character (w) variants, which
        # is half the artifact set; the un-suffixed link names are aliased
        # onto them further down.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --with-shared \
            --without-debug \
            --without-normal \
            --with-cxx-shared \
            --enable-pc-files \
            --with-pkg-config-libdir=$OUT/lib/pkgconfig \
            --disable-stripping
        # include/ncurses_cfg.hin: configure.in:44 is
        # AC_CONFIG_HEADERS([include/ncurses_cfg.h:include/ncurses_cfg.hin]).
        # ncurses has no configure.ac, so a lookup for one finds nothing.
        touch aclocal.m4 configure include/ncurses_cfg.hin
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
        # Preserve traditional link names expected by consumers.
        # Consumers in this tree link the un-suffixed names (curses, form,
        # menu, panel); ncurses builds only the wide-char ones, so alias them
        # here. Same shape as the libpng libzlib -> libz alias in
        # packages/libpng/generic.lua.
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
