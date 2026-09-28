require("termcap")
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
    ]]
})
