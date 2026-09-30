require("freetype")
require("fribidi")
require("harfbuzz@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/harfbuzz/* .
        # Static library with the FreeType and FriBidi integrations, found
        # through this prefix's pkg-config path, plus ICU-free core shaping.
        # The tests are a host program suite built against googletest, and the
        # utilities are host programs; both stay off.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dintrospection=disabled -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dgraphite=disabled
        ninja -C build
        ninja -C build install
    ]]
})
