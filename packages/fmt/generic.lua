require("fmt@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/fmt/* .
        # Static library, header and pkg-config file. FMT_TEST is the host
        # test suite and is off. FMT_INSTALL pulls the headers and the .pc
        # file in. There is no bundled program to worry about: fmt 11.1.4's
        # CMakeLists.txt contains no add_executable at all (verified), so no
        # binary is built. An earlier version of this comment referred to
        # "the bundled program" as something FMT_TEST turned off, which was
        # never true.
        cmake -S . -B build $CMAKE_FLAGS -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=ON -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
