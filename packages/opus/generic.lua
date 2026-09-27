require("opus@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/opus/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --disable-doc --disable-extra-programs
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
