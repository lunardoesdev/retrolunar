require("libcbor@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libcbor/* .
        # CMake build. WITH_EXAMPLES off: upstream's default builds nine
        # target example programs that a prefix has no use for, and
        # examples/CMakeLists.txt also probes for cJSON, which would drag a
        # host package search into the build. WITH_TESTS is off upstream's
        # default already (it needs CMocka). SANITIZE off: upstream's default
        # adds ASan/UBSan flags to the Debug config, and we never build Debug.
        # CMAKE_C_STANDARD=99 pins upstream's own documented default. Upstream
        # probes for the C23 "nodiscard" attribute and, when the probe
        # succeeds, switches the whole build to -std=c23, which upstream's own
        # comment calls out as a mode that "may fail". C99 is what the project
        # asks for everywhere else in the file, so ask for it explicitly.
        # (The probe succeeds on all our toolchains, so without this flag every
        # system would land in C23 mode.)
        cmake -S . -B build $CMAKE_FLAGS -DWITH_EXAMPLES=OFF -DSANITIZE=OFF -DCMAKE_C_STANDARD=99
        cmake --build build --parallel 1
        cmake --install build
    ]]
})