require("fmt@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/fmt/* .
        # Static library, header and pkg-config file. FMT_TEST and the
        # bundled program are host programs; FMT_INSTALL pulls the headers
        # and the .pc file in.
        cmake -S . -B build $CMAKE_FLAGS -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=ON -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
