require("xz@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xz/* .
        # NLS and the unxz/lzmadec helpers are off because gettext and the
        # optional lzma tooling are not part of this target prefix.
        # --disable-shared is a deliberate policy correction, not a
        # necessity: libtool's default builds both, so this package was the
        # odd one out in a prefix where 27 of ~150 packages pass
        # --disable-shared. Its shared object is NOT load-bearing the way
        # binutils' libbfd or e2fsprogs' libext2fs are, and the five
        # consumers here (elfutils, ffmpeg, libarchive, minizip-ng, and
        # kmod/libtiff/zstd for liblzma) all reach it through pkg-config and
        # link the archive. The artifact changes from lib/liblzma.so to
        # lib/liblzma.a; topackage.md:87 still records the shared object and
        # needs updating by the builder.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-nls \
            --disable-shared \
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
