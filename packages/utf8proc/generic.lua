require("utf8proc@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/utf8proc/* .
        # Static library, header and the data tables. utf8proc compiles its
        # Unicode tables into the library, so there is no data to install.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
