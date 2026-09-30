require("flatbuffers@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flatbuffers/* .
        # The C++ library plus flatc, the schema compiler: without flatc a
        # consumer cannot generate its own headers from a .fbs schema, so it
        # belongs in the prefix even though it is a program.
        cmake -S . -B build $CMAKE_FLAGS -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_GRPCTEST=OFF -DFLATBUFFERS_BUILD_SHAREDLIB=OFF -DFLATBUFFERS_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
