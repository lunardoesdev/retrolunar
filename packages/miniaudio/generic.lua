require("miniaudio@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/miniaudio/* .
        # miniaudio is a single-header library AND an optional convenience
        # library: CMakeLists.txt:505 builds miniaudio.c into a real
        # libminiaudio, which is installed alongside the header. It is
        # optional in the sense that a consumer may instead
        # #define MINIAUDIO_IMPLEMENTATION in its own translation unit, but
        # this recipe builds the library because it is what upstream's install
        # rules produce.
        #
        # MINIAUDIO_BUILD_EXAMPLES, MINIAUDIO_BUILD_TESTS and
        # MINIAUDIO_BUILD_TOOLS all default OFF (CMakeLists.txt:17-19) and are
        # passed explicitly because all three are host programs.
        # MINIAUDIO_INSTALL=ON is the default (line 73) and is what installs
        # miniaudio.h, miniaudio.pc and the optional extras headers.
        #
        # Installed: include/miniaudio/miniaudio.h, libminiaudio, miniaudio.pc,
        # and the extras headers for any backends and node-graph nodes that
        # get enabled. The .pc IS shipped: miniaudio.pc.in is configured at
        # CMakeLists.txt:867 and installed at :869-870 whenever
        # MINIAUDIO_INSTALL is on, which this recipe turns on explicitly.
        # (An earlier version of this recipe claimed there was no .pc; that
        # was wrong.)
        cmake -S . -B build $CMAKE_FLAGS -DMINIAUDIO_INSTALL=ON -DMINIAUDIO_BUILD_EXAMPLES=OFF -DMINIAUDIO_BUILD_TESTS=OFF -DMINIAUDIO_BUILD_TOOLS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
