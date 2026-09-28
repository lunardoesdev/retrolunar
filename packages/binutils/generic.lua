require("zlib")
require("binutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/binutils/* .
        # Use the staged Zlib package and build the 64-bit BFD tools.
        # gprofng uses pthread cancellation APIs absent from the Android 24 NDK.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --enable-ld=default \
            --enable-plugins \
            --enable-shared \
            --disable-werror \
            --enable-64-bit-bfd \
            --enable-new-dtags \
            --with-system-zlib \
            --disable-gprofng \
            --enable-default-hash-style=gnu
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 tooldir="$OUT"
        make -j1 tooldir="$OUT" install
    ]]
})
