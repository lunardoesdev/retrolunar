require("msgpack-c@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/msgpack-c/* .
        # C++ library, headers and pkg-config files for msgpack and msgpack-c.
        # The benchmarks and the other language implementations in the tree
        # are host-side and stay off.
        cmake -S . -B build $CMAKE_FLAGS -DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_BENCHMARKS=OFF -DMSGPACK_ENABLE_CXX=ON -DMSGPACK_ENABLE_C=OFF -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
