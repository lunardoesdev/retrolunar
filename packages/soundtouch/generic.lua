require("soundtouch@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/soundtouch/* .
        # CMake, not Autotools: the dist tarball ships configure.ac and
        # Makefile.am but no generated configure, so ./configure would need
        # autoreconf with native autotools. Its own CMakeLists.txt is
        # first-class and needs no bootstrap. This is the same shape
        # packages/wolfssl/generic.lua takes.
        #
        # Static library, headers, soundtouch.pc and a CMake package config.
        # SOUNDSTRETCH=OFF: the soundstretch command-line utility defaults ON
        # (CMakeLists.txt:112) and is a host program that would link the
        # target library and, worse, transcode audio if run.
        # SOUNDTOUCH_DLL=OFF is upstream's default (line 135) and is the
        # Windows DLL wrapper - a shared library a target prefix has no loader
        # path for. Passed explicitly so that is a decision, not a default.
        # BUILD_SHARED_LIBS=OFF for the same reason as everywhere else.
        #
        # NEON defaults ON (line 75) and is selected by the compiler for ARM
        # targets; nothing needs turning off for it.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DSOUNDSTRETCH=OFF -DSOUNDTOUCH_DLL=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
