require("zlib@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zlib/* .
        cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_PREFIX_PATH=$PREFIX -DZLIB_BUILD_EXAMPLES=OFF
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        DESTDIR="$OUT" cmake --install build
    ]]
})
