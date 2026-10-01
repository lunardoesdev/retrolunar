require("kissfft@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/kissfft/* .
        # Static libkissfft.a, the kiss_fft*.h headers, kissfft.pc and the
        # CMake package config. KISSFFT_STATIC is upstream's own switch
        # (CMakeLists.txt:50), not BUILD_SHARED_LIBS.
        #
        # KISSFFT_TEST must be off: it defaults ON and test/CMakeLists.txt:32
        # does pkg_check_modules(fftw3 REQUIRED ...), so leaving it on makes
        # the test tree hard-require an FFTW that may not be in the prefix,
        # and test/CMakeLists.txt:44 builds testcpp.cc, a C++ program.
        # KISSFFT_TOOLS is off for the same reason the other libraries here
        # drop their programs: kfc reads kiss_fft.c at runtime and is not part
        # of the library.
        cmake -S . -B build $CMAKE_FLAGS -DKISSFFT_STATIC=ON -DKISSFFT_TEST=OFF -DKISSFFT_TOOLS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})