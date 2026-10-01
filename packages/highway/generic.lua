require("highway@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/highway/* .
        # Static libhwy.a + libhwy_contrib.a, the hwy/ header tree (including
        # every hwy/contrib/ subdirectory), libhwy.pc + libhwy-contrib.pc and
        # a CMake package config under lib/cmake/hwy.
        #
        # Highway is NOT header-only. It ships real per-target SIMD kernels:
        # hwy/detect_targets.h picks HWY_TARGETS from compiler-predefined
        # macros (__ARM_NEON__ at :515, __SSE2__ and friends), never from a
        # cmake-detected host, so the cross compiler itself selects the right
        # kernels and a cross build needs no target override here.
        #
        # BUILD_SHARED_LIBS=OFF: CMakeLists.txt:515 already defaults it OFF and
        # :526-528 then picks HWY_LIBRARY_TYPE=STATIC, which is what we want -
        # a target prefix has no loader path for libhwy.so. Passed explicitly
        # so the static choice is visible. HWY_FORCE_STATIC_LIBS (:516) is the
        # belt-and-braces switch and is redundant once BUILD_SHARED_LIBS=OFF.
        #
        # HWY_ENABLE_TESTS=OFF is load-bearing twice over. It defaults ON
        # (CMakeLists.txt:88). Left on, :794-806 configure_file +
        # execute_process DOWNLOADS googletest over the network at configure
        # time and builds it - no network access is allowed at build time
        # except curl in source.lua, and no recipe runs git. It then compiles
        # ~70 host test executables (:941-975) and calls gtest_discover_tests
        # on each, which RUNS every one of them at build time. Turning it off
        # also drops libhwy-test from the install (:672-686) and drops
        # libhwy-test.pc, whose Requires: is gtest (:713).
        #
        # HWY_ENABLE_EXAMPLES=OFF: also defaults ON (:86). It builds four
        # example programs (:733-775), none of them installed.
        #
        # HWY_ENABLE_CONTRIB stays ON (:85, default). It is the whole point of
        # the second library and of hwy/contrib/**, and :167-169 only requires
        # Threads, which the systems provide (and the Android systems already
        # set THREADS_PREFER_PTHREAD_FLAG=ON because FindThreads cannot detect
        # Bionic's libc-resident pthreads on a cross build).
        #
        # HWY_ENABLE_INSTALL stays ON (:87) - the library and the headers are
        # what we are here for.
        #
        # hwy_list_targets (:620) is built unconditionally and is NOT gated by
        # any of these options. Its POST_BUILD step at :631-633 runs the binary
        # but is wrapped in `if (NOT CMAKE_CROSSCOMPILING OR
        # CMAKE_CROSSCOMPILING_EMULATOR)`, so on every cross system here it is
        # skipped. cmake reports CMAKE_CROSSCOMPILING=TRUE for our toolchains
        # even though they deliberately set CMAKE_SYSTEM_NAME to Linux, so the
        # guard holds. It is not installed. Nothing in the recipe can turn it
        # off, and nothing needs to: it neither runs nor installs.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DHWY_ENABLE_CONTRIB=ON -DHWY_ENABLE_INSTALL=ON -DHWY_ENABLE_TESTS=OFF -DHWY_ENABLE_EXAMPLES=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
