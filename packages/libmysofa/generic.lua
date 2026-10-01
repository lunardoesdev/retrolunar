require("libmysofa@source")
require("zlib")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libmysofa/* .
        # CMake. There is no autotools build; the only config template in the
        # tree is src/config.h.in, which is the cmake one consumed by
        # configure_file at src/CMakeLists.txt:3, so no timestamp guard is
        # involved.
        #
        # -DBUILD_TESTS=OFF is the flag that must not be missed, and for two
        # separate reasons. BUILD_TESTS defaults ON (CMakeLists.txt:8), and
        # src/CMakeLists.txt:156 makes it find_package(CUnit REQUIRED);
        # CUnit is neither in this prefix nor anywhere in the package
        # backlog, so configure would abort outright. It also compiles
        # src/tests/multithread.c, whose pthread_cancel
        # (src/tests/multithread.c:147) is one of the calls Bionic withholds
        # before API 24, so on android21 it would fail to compile even if
        # CUnit were present.
        #
        # Static only: BUILD_SHARED_LIBS defaults ON (CMakeLists.txt:9) and a
        # target prefix here has no loader path for a versioned object.
        # BUILD_STATIC_LIBS is the default (:10) and is stated so the pair
        # reads as one decision.
        #
        # zlib comes from this prefix, hence the require() above. It is a
        # real link dependency, not a build-time nicety: src/hdf/gunzip.c is
        # in the library source list (src/CMakeLists.txt:37), and the same
        # block adds -lz -lm to Libs.private (src/CMakeLists.txt:14-15).
        # include(FindZLIB) at src/CMakeLists.txt:12 resolves it through
        # $CMAKE_PREFIX_PATH, which $CMAKE_FLAGS already points at $PREFIX.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
