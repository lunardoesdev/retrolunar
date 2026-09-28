require("libiconv")
require("onnxruntime@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/onnxruntime/* .
        cmake -S cmake -B build $CMAKE_FLAGS \
          -DBUILD_SHARED_LIBS=OFF \
          -Donnxruntime_BUILD_SHARED_LIB=OFF \
          -Donnxruntime_BUILD_UNIT_TESTS=OFF \
          -Donnxruntime_BUILD_BENCHMARKS=OFF \
          -DBUILD_TESTING=OFF \
          -Donnxruntime_ENABLE_PYTHON=OFF \
          -Donnxruntime_USE_XNNPACK=OFF \
          -Donnxruntime_BUILD_FOR_NATIVE_MACHINE=OFF
        cmake --build build
        cmake --install build
    ]]
})
