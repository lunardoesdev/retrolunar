require("zlib")
require("libjpeg-turbo")
require("libpng")
require("libtiff")
require("libwebp")
require("openjpeg")
require("opencv@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/opencv/* .
        cmake -S . -B build $CMAKE_FLAGS \
          -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF \
          -DBUILD_DOCS=OFF -DBUILD_JAVA=OFF -DBUILD_OBJC=OFF \
          -DBUILD_opencv_apps=OFF -DBUILD_opencv_java_bindings_generator=OFF \
          -DBUILD_JPEG=OFF -DBUILD_PNG=OFF -DBUILD_TIFF=OFF -DBUILD_WEBP=OFF \
          -DWITH_TIFF=OFF \
          -DBUILD_LIST=core,imgproc,imgcodecs,videoio
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
