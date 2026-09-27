require("xz@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xz/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --disable-doc --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts
        # Timestamps from the tarball trip Automake re-runs (needs
        # aclocal-1.17 which we don't have): mark generated files newer.
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4) -C src/liblzma
        make -C src/liblzma install
    ]]
})
