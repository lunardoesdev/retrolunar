require("zlib")
require("libpng")
require("freetype@source")

return recipe({
    build = [[
        export CPPFLAGS="-I$PREFIX/include -I$PREFIX/include/libpng16"
        export CFLAGS="-O2 -fPIC -I$PREFIX/include -I$PREFIX/include/libpng16 -DANDROID"
        cp -r $NESTDIR/source/freetype/* .
        meson setup build $MESON_FLAGS \
            -Dzlib=system -Dpng=enabled \
            -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
            -Dtests=disabled
        ninja -C build install
    ]]
})
