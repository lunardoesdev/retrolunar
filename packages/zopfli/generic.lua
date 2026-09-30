require("zopfli@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zopfli/* .
        # CMake build, static only. ZOPFLI_BUILD_INSTALL is on by default for
        # a standalone build and its install(TARGETS) covers both libraries
        # and both tools in one rule, so naming only the library target would
        # leave the install step without files to copy. All four are cheap.
        cmake -S . -B build $CMAKE_FLAGS -DZOPFLI_BUILD_SHARED=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})