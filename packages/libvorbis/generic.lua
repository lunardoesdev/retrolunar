require("libogg")
require("libvorbis@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvorbis/* .
        # Static libraries against the libogg in our prefix, and documentation
        # off: this is a library package, not a manual to read on a phone.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-docs --disable-examples
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
