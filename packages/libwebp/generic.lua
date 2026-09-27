require("libwebp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libwebp/* .
        cmake -S . -B build $CMAKE_FLAGS -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_LIBWEBPMUX=OFF -DWEBP_BUILD_LIBWEBPDEMUX=OFF -DBUILD_SHARED_LIBS=OFF
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
