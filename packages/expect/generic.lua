require("tcl")
require("expect@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/expect/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --with-tcl="$PREFIX/lib" \
            --enable-shared \
            --disable-rpath \
            --mandir="$OUT/share/man" \
            --with-tclinclude="$PREFIX/include"
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
