require("tomlplusplus@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tomlplusplus/* .
        # Header-only: the install target copies toml.hpp, toml_forward.hpp
        # and toml.h and generates the CMake package config. Tests off; they
        # are a host C++ suite.
        cmake -S . -B build $CMAKE_FLAGS -DTOMLPLUSPLUS_BUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
