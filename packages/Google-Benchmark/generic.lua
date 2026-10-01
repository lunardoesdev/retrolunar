require("Google-Benchmark@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/Google-Benchmark/* .
        # Static libbenchmark.a, the benchmark/ headers, benchmark.pc and
        # benchmark_main, plus a CMake package config.
        #
        # BENCHMARK_ENABLE_TESTING=OFF is the single switch that matters and it
        # is load-bearing. CMakeLists.txt:348 wraps the whole test block in it,
        # and that block is what reaches for GoogleTest: at :353 it includes
        # cmake/GoogleTest.cmake.in, which looks for a gtest source tree and,
        # failing that, would try to fetch googletest over the network with
        # ExternalProject. Turning the block off removes the gtest dependency,
        # the network fetch and the host test binaries in one move. The two
        # finer switches are left at their defaults because the outer gate
        # already covers them, and passing them would be redundant flags:
        # BENCHMARK_ENABLE_GTEST_TESTS (:40) and BENCHMARK_USE_BUNDLED_GTEST
        # (:41) are both only consulted inside that block.
        #
        # BENCHMARK_ENABLE_INSTALL stays ON (:29, default ON): the archive,
        # headers, the two .pc files and the CMake config all hang off it
        # (src/CMakeLists.txt:135-161). BENCHMARK_INSTALL_DOCS (:31) installs
        # README.md and is harmless. BENCHMARK_INSTALL_TOOLS (:32) covers the
        # Python reporting scripts, which are data.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBENCHMARK_ENABLE_TESTING=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})