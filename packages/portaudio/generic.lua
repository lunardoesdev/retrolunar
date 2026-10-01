require("portaudio@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/portaudio/* .
        # CMake, not Autotools. The release ships both build systems and the
        # autotools one is unusable here for two independent reasons:
        # (1) configure.in:393 is
        #       AC_CHECK_LIB(pthread, pthread_create, [have_pthread="yes"],
        #               AC_MSG_ERROR([libpthread not found!]))
        #     so ./configure aborts outright on any toolchain without
        #     -lpthread. Bionic keeps pthreads in libc and the NDK ships no
        #     libpthread at all: linking a pthread_create() call with
        #     aarch64-linux-android24-clang -lpthread fails with
        #     "ld.lld: error: unable to find library -lpthread".
        # (2) Makefile.in:159 makes "all" build 29 test programs, 9 examples
        #     and 3 selftests (Makefile.in:86-116, :70-79, :81-84) with no
        #     configure switch to stop it, and those programs open audio
        #     devices. Only "install" (Makefile.in:190) is free of them.
        # The CMake path builds the library alone by default.
        #
        # Static only: PA_BUILD_SHARED defaults ON (CMakeLists.txt:350) and a
        # target prefix here has no loader path for a versioned object.
        # PA_BUILD_STATIC is the default too (:349) and is stated so the pair
        # reads as one decision.
        #
        # ALSA and JACK are forced off. Upstream auto-detects both
        # (CMakeLists.txt:277, :294) and each has an else-branch that turns
        # its option off when the library is missing (:281, :299) - but this
        # build HOST has libasound and libjack installed, so autodetection
        # would switch them ON and bake -lasound/-ljack into the installed
        # portaudio-2.0.pc. That is a build-host audio stack leaking into the
        # target prefix, so neither is left to autodetect.
        #
        # Tests and examples are already OFF upstream
        # (CMakeLists.txt:478, :484); stated here so a future default flip
        # cannot start compiling host programs.
        cmake -S . -B build $CMAKE_FLAGS -DPA_BUILD_STATIC=ON -DPA_BUILD_SHARED=OFF -DPA_USE_ALSA=OFF -DPA_USE_JACK=OFF -DPA_BUILD_TESTS=OFF -DPA_BUILD_EXAMPLES=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
