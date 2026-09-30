-- libnl-3 turns src/*.l and src/*.y into C at build time, and the release
-- tarball ships only the .l/.y sources (the .c/.h are in CLEANFILES), so
-- flex and bison have to be present as host executables.
require("flex@native")
require("bison@native")
require("libnl-3@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libnl-3/* .
        # Static with PIC. The default --enable-cli=yes builds 51 command
        # line tools, and with it libnl-cli-3 (the only object that links
        # -ldl); the libraries themselves need neither.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --enable-cli=no
        touch aclocal.m4 configure include/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
