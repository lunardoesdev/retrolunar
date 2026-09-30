require("zlib-ng@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zlib-ng/* .
        # zlib-ng is a drop-in zlib replacement with SIMD paths for the
        # hot functions (adler32, crc32, deflate, inflate). Built native (not
        # zlib-compat) so callers get the zlib API and the optimised code at
        # once. The examples and minizip-ng are host programs; the library is
        # what a prefix is for.
        cmake -S . -B build $CMAKE_FLAGS -DZLIB_COMPAT=OFF -DZLIB_ENABLE_TESTS=OFF -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
