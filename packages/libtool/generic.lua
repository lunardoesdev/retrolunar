require("m4")
require("libtool@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libtool/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --disable-fortran --without-gcj
        touch aclocal.m4 configure config-h.in
        find . -name 'Makefile.in' | xargs touch
        touch -d '+1 day' aclocal.m4
        find . -name 'Makefile.in' | xargs touch -d '+1 day'
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
