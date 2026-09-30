require("abseil-cpp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/abseil-cpp/* .
        # One static archive per module, the absl/ headers, one
        # absl_<module>.pc per module and a lib/cmake/absl package config.
        # BUILD_SHARED_LIBS=OFF: this prefix is static, and a shared absl
        # would want a loader path a target has no use for.
        # ABSL_BUILD_TESTING=OFF is the switch that keeps the build offline
        # and host-free. ABSL_BUILD_TEST_HELPERS is already OFF, but the two
        # together are the whole gate: when either is on and
        # ABSL_USE_EXTERNAL_GOOGLETEST is off, top-level CMakeLists.txt
        # includes CMake/Googletest/DownloadGTest.cmake, which fetches
        # GoogleTest at configure time and configures and builds it with a
        # host compiler. That is a network fetch and a host build in the
        # middle of a cross build.
        # Upstream ships no aggregate absl.pc, so consumers use
        # find_package(absl) or the per-module .pc files.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DABSL_BUILD_TESTING=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
