require("termcap")
require("readline@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/readline/* .
        # Python links readline into a shared module: objects need -fPIC.
        export CFLAGS="$CFLAGS -fPIC"
        # Use the existing termcap dependency instead of adding ncurses here.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-curses
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
