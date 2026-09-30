require("libconfig@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libconfig/* .
        # CMake build, static only. The examples and the test programs are
        # target executables that nothing in a prefix needs, and libconfig's
        # CMakeLists has no switch to build the library alone without them.
        # BUILD_CXX stays on: the C++ binding is part of what libconfig is,
        # and it is a separate archive with its own pkg-config file.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})