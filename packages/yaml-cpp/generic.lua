require("yaml-cpp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/yaml-cpp/* .
        # Static library, headers, pkg-config file and the C++ ABI toggle.
        # Tests, tools and utilities are host programs and stay off.
        cmake -S . -B build $CMAKE_FLAGS -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF -DYAML_CPP_BUILD_UTILS=OFF -DYAML_BUILD_SHARED_LIBS=OFF -DYAML_CPP_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
