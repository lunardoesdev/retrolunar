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
        # No upstream .pc ships: write one so readline's
        # Requires.private: termcap resolves via pkg-config.
        mkdir -p $OUT/lib/pkgconfig
        printf 'prefix=%s\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\nName: termcap\nDescription: GNU termcap\nVersion: 1.3.1\nLibs: -L${libdir} -ltermcap\nCflags: -I${includedir}\n' "$PREFIX" > $OUT/lib/pkgconfig/termcap.pc
    ]]
})
