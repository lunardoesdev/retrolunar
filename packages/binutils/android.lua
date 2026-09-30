require("zlib")
require("binutils@source")

-- Found for every Android target through the systems' recipe_fallbacks,
-- so there is no per-target copy of this recipe.
return recipe({
    build = [[
        cp -r $NESTDIR/source/binutils/* .
        # Android lacks pthread cancellation APIs used by gprofng.
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
