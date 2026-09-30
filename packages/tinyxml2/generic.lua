require("tinyxml2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tinyxml2/* .
        # Static library, header and pkg-config file. Tools and tests stay off:
        # xmltest and tinystr are host programs, and a prefix is for the
        # library.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -Dtinyxml2_BUILD_TOOLS=OFF -Dtinyxml2_BUILD_TESTING=OFF -Dtinyxml2_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
