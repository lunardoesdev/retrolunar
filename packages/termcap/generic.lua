require("termcap@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/termcap/* .
        # termcap 1.3.1 predates prototypes: needs pre-C23 (NDK clang
        # defaults to C23 where implicit declarations are errors).
        export CC="$CC -std=gnu89"
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
