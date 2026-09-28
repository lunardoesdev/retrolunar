require("readline@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/readline/* .
        # Python links readline into a shared module: objects need -fPIC.
        export CFLAGS="$CFLAGS -fPIC"
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-curses
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
        # objects ship inside libreadline itself (--without-curses, no
        # external termcap lib). Satisfy pkg-config with an empty stub.
        printf 'Name: termcap\nDescription: stub (termcap folded into libreadline)\nVersion: 8.3\nLibs:\nCflags:\n' > $OUT/lib/pkgconfig/termcap.pc
    ]]
})
