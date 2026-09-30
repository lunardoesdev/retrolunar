require("catch2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/catch2/* .
        # Catch2 v3 is a real compiled library (libCatch2.a plus the
        # Catch2Main library) rather than a header-only bundle, so this is a
        # genuine compile. Tests off: they are host programs and they are
        # also the slowest part of Catch2's own build.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DCATCH_INSTALL_DOCS=OFF -DCATCH_INSTALL_EXTRAS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
