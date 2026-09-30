require("nlohmann-json@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/nlohmann-json/* .
        # Header-only library: the install target copies the single-header
        # distribution and generates CMake and pkg-config files from it.
        # Nothing is compiled, so no toolchain, no sysroot, no cross
        # compiler: a header-only package is the same on every system.
        cmake -S . -B build $CMAKE_FLAGS -DJSON_BuildTests=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
