require("soxr@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/soxr/* .
        # CMake. soxr has no autotools build at all, so there is no config
        # header template to guard and no ./configure.
        #
        # BUILD_TESTS defaults ON (CMakeLists.txt:43) and is the switch that
        # matters: tests/CMakeLists.txt globs every tests/*.c and gives each
        # its own add_executable, so the default builds five target binaries
        # for a package whose deliverable is a library. BUILD_EXAMPLES is
        # dragged in by the same option (CMakeLists.txt:288) and additionally
        # needs a C++ compiler (CMakeLists.txt:104), so it goes off too.
        # BUILD_LSR_TESTS is already suppressed whenever cmake is
        # cross-compiling (CMakeLists.txt:73), but is stated so the native
        # build matches the cross ones instead of differing by default.
        #
        # BUILD_SHARED_LIBS defaults ON (:48) and a target prefix here has no
        # loader path for a versioned object, so static only.
        #
        # WITH_OPENMP defaults ON (:45) and find_package(OpenMP) would append
        # -fopenmp to the compile line. The resampler is single-threaded, so
        # that would only make the compiled result depend on whether OpenMP
        # happened to be found on the build host.
        #
        # WITH_LSR_BINDINGS stays ON (:46): it is a second shipped library,
        # libsoxr-lsr (src/CMakeLists.txt:100-118), not a test.
        #
        # Nothing is compiled and run on the build host. The one executable
        # soxr would otherwise generate, vr-coefs, is guarded by
        # "if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/vr-coefs.h)"
        # (src/CMakeLists.txt:8), and the release ships that header (5,336
        # bytes), so the generator is never even built - which is what
        # src/CMakeLists.txt:6 means by "it complicates cross-compiling".
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_LSR_TESTS=OFF -DWITH_OPENMP=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
