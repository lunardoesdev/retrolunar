require("zlib")
require("libpng@source")

return recipe({
    build = [[
        export CPPFLAGS="-I$PREFIX/include"
        export LDFLAGS="-L$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib"
        cp -r $NESTDIR/source/libpng/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-zlib-prefix="$PREFIX"
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
