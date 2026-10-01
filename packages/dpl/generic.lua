require("dpl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/dpl/* .
        # Header-only: add_library(oneDPL INTERFACE) at CMakeLists.txt:151, so
        # nothing is compiled and the install is a file copy identical on every
        # system.
        #
        # ONEDPL_BACKEND is the switch that decides whether oneDPL is usable
        # standalone. Left unset it defaults to "tbb" whenever SYCL is absent
        # (CMakeLists.txt:138-146), and that path runs
        # find_package(TBB 2021 REQUIRED ...) at line 211 and links
        # TBB::tbb. "serial" instead compiles the headers with every parallel
        # backend macro forced to 0 (lines 283-289) and requires no external
        # library at all, so oneDPL configures and installs without oneTBB in
        # the prefix. ONEDPL_BACKEND is passed through the cache to the
        # installed dpl.pc/config, so this is visible to consumers.
        #
        # The test tree is entered whenever oneDPL is the top-level project
        # (CMakeLists.txt:356-359), but every target in it is declared
        # EXCLUDE_FROM_ALL (test/CMakeLists.txt:92 and test/kt/CMakeLists.txt:26),
        # so "cmake --build" compiles none of them. examples/ is not added at
        # all - the only add_subdirectory outside test/ is
        # cmake/post_install in oneTBB, not here.
        #
        # ONEDPL_ENABLE_SIMD stays ON (line 29): it only adds an -fopenmp-simd
        # style flag to the INTERFACE target after check_cxx_compiler_flag
        # accepts it, so it is a no-op on a compiler that lacks it.
        cmake -S . -B build $CMAKE_FLAGS -DONEDPL_BACKEND=serial
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
