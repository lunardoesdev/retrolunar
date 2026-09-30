require("libogg@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libogg/* .
        # libogg is the container every other Xiph codec sits on, so it is
        # built static, with the programs off: a target prefix wants the
        # archive, headers and pkg-config files.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-oggtest --disable-vorbistest
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
