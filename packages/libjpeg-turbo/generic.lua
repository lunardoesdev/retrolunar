require("libjpeg-turbo@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libjpeg-turbo/* .
        cmake -S . -B build $CMAKE_FLAGS -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_JPEG8=ON
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
