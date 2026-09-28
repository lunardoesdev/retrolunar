require("protobuf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/protobuf/* .
        cmake -S . -B build $CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_EXAMPLES=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_BUILD_LIBPROTOC=ON
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
