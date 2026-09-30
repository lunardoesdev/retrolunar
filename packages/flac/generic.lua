require("libogg")
require("flac@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flac/* .
        # Static libraries against the libogg in this prefix: libFLAC (the
        # format), libFLAC++ (the C++ decoder interface) and the plugins.
        # The command line tools and the test suite are host programs and
        # stay off.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-oggtest
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
