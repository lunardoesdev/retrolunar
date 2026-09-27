require("openjpeg@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openjpeg/* .
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_CODEC=OFF
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
