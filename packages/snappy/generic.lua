require("snappy@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/snappy/* .
        # Static library, library and headers only: the tests and the
        # benchmarks are host programs that would just be dead weight in a
        # target prefix.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
