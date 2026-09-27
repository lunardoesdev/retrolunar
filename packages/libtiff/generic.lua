require("zlib")
require("libjpeg-turbo")
require("libtiff@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libtiff/* .
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-contrib=OFF -Dtiff-docs=OFF -Dwebp=OFF -Dlerc=OFF -Dzstd=OFF -Dlibdeflate=OFF -Dlzma=ON -Djpeg=ON
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
