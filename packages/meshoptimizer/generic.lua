require("meshoptimizer@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/meshoptimizer/* .
        # Static libmeshoptimizer.a, meshoptimizer.h and a CMake package
        # config under lib/cmake/meshoptimizer. MESHOPT_BUILD_DEMO and
        # MESHOPT_BUILD_GLTFPACK are already OFF upstream, passed explicitly
        # because both are host programs: gltfpack in particular is a
        # standalone command-line tool with its own JSON and image decoders,
        # and this prefix is for the library. MESHOPT_INSTALL=ON pulls in the
        # header and the package config.
        cmake -S . -B build $CMAKE_FLAGS -DMESHOPT_BUILD_DEMO=OFF -DMESHOPT_BUILD_GLTFPACK=OFF -DMESHOPT_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
