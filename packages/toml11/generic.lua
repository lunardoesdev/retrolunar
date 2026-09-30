require("toml11@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/toml11/* .
        # Header-only library: the install copies the headers into
        # include/toml11 and into include/toml (the compatibility path) and
        # generates the cmake config. Tests off: they are a host C++ suite.
        cmake -S . -B build $CMAKE_FLAGS -DTOML11_BUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
