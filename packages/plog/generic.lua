require("plog@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/plog/* .
        # Header-only library: plog is a single header (include/plog/Log.h)
        # and its CMake target is an INTERFACE library (CMakeLists.txt:24),
        # so nothing is compiled and the install is a file copy that is
        # identical on every system. cmake runs only to drive the install
        # rules; $CMAKE_FLAGS is passed for consistency with the rest of the
        # tree and nothing else.
        #
        # PLOG_BUILD_SAMPLES=OFF: it defaults to ON whenever plog is the
        # top-level project (CMakeLists.txt:17), and samples/ builds host
        # programs. PLOG_BUILD_TESTS=OFF is already the default (line 19) and
        # is passed explicitly for the same reason. PLOG_INSTALL=ON is the
        # whole point of the run.
        #
        # Installed: include/plog/, a CMake package config under
        # lib/cmake/plog/, and README.md + LICENSE. No library file and no
        # pkg-config file - upstream ships neither.
        cmake -S . -B build $CMAKE_FLAGS -DPLOG_BUILD_SAMPLES=OFF -DPLOG_BUILD_TESTS=OFF -DPLOG_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
