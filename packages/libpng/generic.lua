require("zlib")
require("libpng@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libpng/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-zlib-prefix="$PREFIX"
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
