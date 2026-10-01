require("cppcheck@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cppcheck/* .
        # CMake-only: cmake_minimum_required(VERSION 3.22) and
        # project(Cppcheck VERSION 2.22.0 LANGUAGES CXX) (CMakeLists.txt:1-2).
        #
        # DISABLE_DMAKE is mandatory, not an optimisation. cli/CMakeLists.txt:38-40
        # does add_dependencies(cppcheck run-dmake), and
        # tools/dmake/CMakeLists.txt:14 defines that target as
        # add_custom_target(run-dmake $<TARGET_FILE:dmake> ...) -- it EXECUTES
        # the freshly cross-compiled dmake binary. On every cross system in
        # this tree that binary is an Android or PE executable, and running it
        # would need an emulator, which this project never does. It defaults
        # to OFF precisely because the release tarball has no git tree for it
        # to read; see option(DISABLE_DMAKE ...) in cmake/options.cmake.
        # What it produces is upstream's own top-level Makefile
        # (tools/dmake/dmake.cpp:609, static constexpr char makefile[] =
        # "Makefile"), which no CMakeLists.txt in the tree references -- the
        # cmake build compiles straight from the file GLOBs at
        # lib/CMakeLists.txt:1-2 -- so nothing the build needs is lost.
        #
        # The analyser library is built as an OBJECT library rather than a
        # shared one (lib/CMakeLists.txt:43-48), matching the rest of this
        # static prefix; BUILD_SHARED_LIBS is stated explicitly rather than
        # left to cmake's default of OFF.
        #
        # No PCRE is needed and none is bundled. option(HAVE_RULES ...)
        # (cmake/options.cmake) is OFF by default, and
        # cmake/findDependencies.cmake:32-38 only probes pcre.h/libpcre when it
        # is on -- as a FATAL_ERROR if missing. This prefix ships pcre2, whose
        # header is pcre2.h, so HAVE_RULES could not be satisfied here anyway.
        # The three third-party pieces cppcheck does need (tinyxml2, simplecpp,
        # picojson) are vendored as real files under externals/, not git
        # submodules -- there is no .gitmodules in the tree -- and
        # USE_BUNDLED_TINYXML2 defaults ON, so nothing is looked up in
        # $PREFIX.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DDISABLE_DMAKE=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})