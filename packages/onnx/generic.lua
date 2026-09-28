require("onnx@source")

-- Schema/defs only: protobuf + C++ headers, no runtime. Enough for
-- codegen against .onnx files; full onnxruntime is a separate beast.
return recipe({
    build = [[
        cp -r $NESTDIR/source/onnx/* .
        cmake -S . -B build $CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DONNX_BUILD_TESTS=OFF -DONNX_USE_PROTOBUF_SHARED_LIBS=OFF -DONNX_USE_LITE_PROTO=ON
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
