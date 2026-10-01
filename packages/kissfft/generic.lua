require("kissfft@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/kissfft/* .
        # Static libkissfft-double.a, the kiss_fft*.h headers, kissfft-double.pc
        # and the CMake package config.
        #
        # KISSFFT_STATIC is upstream's own switch (CMakeLists.txt:50), not
        # BUILD_SHARED_LIBS; it defaults OFF, so passing the wrong one would
        # produce a shared libkissfft*.so in a prefix with no loader path.
        #
        # KISSFFT_TEST must be off: it defaults ON and
        # test/CMakeLists.txt:32 does pkg_check_modules(fftw3 REQUIRED ...),
        # so leaving it on makes the test tree hard-REQUIRE an fftw3.pc that
        # may not be in the prefix -- a fatal configure error, not a skipped
        # test. test/CMakeLists.txt:44 also builds testcpp.cc, a C++ program.
        # KISSFFT_TOOLS is off for the same reason the other libraries here
        # drop their programs: kfc reads kiss_fft.c at runtime.
        #
        # KISSFFT_DATATYPE is pinned, and it has to be. It defaults to
        # "float" (CMakeLists.txt:44) and the datatype is baked into BOTH
        # output names: CMakeLists.txt:72 sets
        # KISSFFT_OUTPUT_NAME=kissfft-${KISSFFT_DATATYPE}, which becomes the
        # archive name at :232-235 and the .pc file at :339-341, whose
        # Libs: is -l@KISSFFT_OUTPUT_NAME@ (kissfft.pc.in:9). So the artifacts
        # are libkissfft-float.a/kissfft-float.pc by default, and leaving it
        # unpinned means an upstream default change silently renames every
        # consumer's link line. double is pinned here because it is the
        # conventional default for a numeric prefix.
        cmake -S . -B build $CMAKE_FLAGS -DKISSFFT_STATIC=ON -DKISSFFT_TEST=OFF -DKISSFFT_TOOLS=OFF -DKISSFFT_DATATYPE=double
        cmake --build build --parallel 1
        cmake --install build
    ]]
})