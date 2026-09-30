require("zlib")
require("libpng")
require("freetype@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/freetype/* .
        # default_library=static: meson builds shared by default and a
        # target prefix has no loader path for a versioned object. FreeType's
        # own default_options (meson.build:305) applies only when it is built
        # as a subproject, which standalone never is. The other switches leave
        # zlib and png as the only backends, both from this prefix, and drop
        # ftdump/ftbench and the test programs.
        meson setup build $MESON_FLAGS -Ddefault_library=static \
            -Dzlib=system -Dpng=enabled \
            -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
            -Dtests=disabled
        ninja -C build install
    ]]
})
