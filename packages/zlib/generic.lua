require("zlib@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zlib/* .
        cmake -S . -B build $CMAKE_FLAGS -DZLIB_BUILD_EXAMPLES=OFF
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
