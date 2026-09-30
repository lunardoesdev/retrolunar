require("doctest@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/doctest/* .
        # Header-only test framework: the install target copies doctest/ into
        # include/doctest and generates the CMake package config. The examples
        # are host programs and stay off.
        cmake -S . -B build $CMAKE_FLAGS -DDOCTEST_WITH_TESTS=OFF -DDOCTEST_WITH_MAIN_IN_STATIC_LIB=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
