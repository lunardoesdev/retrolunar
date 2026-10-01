require("tl-expected@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tl-expected/* .
        # Header-only: add_library(expected INTERFACE) at CMakeLists.txt:28, so
        # nothing is compiled and the install is a file copy identical on every
        # system. cmake runs only to drive the install rules and to generate the
        # package config.
        #
        # EXPECTED_BUILD_TESTS is a cmake_dependent_option defaulting ON when
        # BUILD_TESTING is on (CMakeLists.txt:20-22), and include(CTest) at line
        # 12 turns BUILD_TESTING on by default. Left alone it would FetchContent
        # a Catch2 zip from github.com (CMakeLists.txt:70-72) and build the
        # test executables, which is both a build-time network fetch and target
        # binaries a cross build must not produce.
        #
        # EXPECTED_BUILD_PACKAGE defaults ON (line 18) and pulls in CPack with
        # DEB and RPM binary generators (lines 97-116), which are host-side
        # packaging steps with no meaning for a target prefix. With it off the
        # build returns at line 87-89 before CPack is included.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_TESTING=OFF -DEXPECTED_BUILD_TESTS=OFF -DEXPECTED_BUILD_PACKAGE=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
