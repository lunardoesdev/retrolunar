require("draco@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/draco/* .
        # Static encoder and decoder, C++ headers and the generated
        # draco_features.h. The tag archive has CMake, not a Makefile, and
        # upstream keeps its build options sparse: tests off is the only thing
        # worth switching off here, the tests are a large gtest suite.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DDRACO_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
