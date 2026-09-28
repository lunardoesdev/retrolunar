require("zlib@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zlib/* .
        # Only the library is used; examples cannot run on the build host.
        cmake -S . -B build $CMAKE_FLAGS -DZLIB_BUILD_EXAMPLES=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
