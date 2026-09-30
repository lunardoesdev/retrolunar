require("pugixml@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/pugixml/* .
        # Static library, header, pkg-config file and the pkg-config-style
        # cmake package config. The tests are off: they are a host program
        # suite and one of the cases needs a network fetch.
        cmake -S . -B build $CMAKE_FLAGS -DPUGIXML_BUILD_TESTS=OFF -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
