require("fmt")
require("spdlog@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/spdlog/* .
        # Static library, headers and pkg-config file. SPDLOG_BUILD_EXAMPLE
        # and the benchmarks are host programs. spdlog does the formatting
        # itself unless SPDLOG_FMT_EXTERNAL is set, which is what the fmt in
        # this prefix is for: one formatting engine in the whole tree.
        cmake -S . -B build $CMAKE_FLAGS -DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_BUILD_EXAMPLE_HOOK=OFF -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_BUILD_BENCH=OFF -DSPDLOG_FMT_EXTERNAL=ON -DBUILD_SHARED_LIBS=OFF -DSPDLOG_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
