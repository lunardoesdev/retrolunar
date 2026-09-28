require("e2fsprogs@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/e2fsprogs/* .
        # Util-linux provides the blkid, uuid and fsck wrappers; this package
        # only needs the shared libraries and the e2fsprogs tools themselves.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --sysconfdir="$OUT/etc" \
            --enable-elf-shlibs \
            --disable-libblkid \
            --disable-libuuid \
            --disable-uuidd \
            --disable-fsck
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
