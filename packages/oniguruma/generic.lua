require("oniguruma@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/oniguruma/* .
        # Static with PIC, like the rest of the prefix. The test/ and sample/
        # subdirectories hold nothing but check_PROGRAMS, which "make all"
        # never builds, so no host programs are compiled here.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
