require("gmp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gmp/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --enable-cxx \
            --disable-static \
            --docdir="$OUT/share/doc/gmp-6.3.0"
        make -j1
        make -j1 install
        make -j1 install-html
    ]]
})
