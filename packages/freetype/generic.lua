require("zlib")
require("libpng")
require("freetype@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/freetype/* .
        meson setup build $MESON_FLAGS \
            -Dzlib=system -Dpng=enabled \
            -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
            -Dtests=disabled
        ninja -C build install
    ]]
})
