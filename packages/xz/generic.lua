require("xz@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xz/* .
        # NLS and the unxz/lzmadec helpers are off because gettext and the
        # optional lzma tooling are not part of this target prefix.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-nls \
            --disable-unxz \
            --disable-lzmadec \
            --disable-lzmainfo \
            --disable-lzlinks \
            --disable-scripts \
            --disable-doc
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
