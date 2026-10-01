require("range-v3@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/range-v3/* .
        # Header-only library: range-v3, range-v3-concepts and range-v3-meta
        # are all INTERFACE targets (CMakeLists.txt:27, :34, :42), so nothing
        # is compiled and the install is a file copy identical on every system.
        # cmake runs only to drive the install rules.
        # range-v3 is NOT option-free: cmake/ranges_options.cmake defines
        # nineteen options, and three of them decide whether anything is
        # compiled at all. RANGE_V3_TESTS, RANGE_V3_EXAMPLES and
        # RANGE_V3_DOCS are CMAKE_DEPENDANT_OPTIONs defaulting ON when
        # `is_standalone` is true (ranges_options.cmake:43, :47, :55), which
        # it is for a top-level build (CMakeLists.txt:12). They drive
        # add_subdirectory at CMakeLists.txt:57, :61 and :65 - so left alone
        # this recipe builds roughly 254 host executables (240 rv3_add_test
        # call sites across the twelve CMakeLists under test/, plus 14 in
        # example/) on every single system, all compiled with
        # RANGES_ENABLE_WERROR=ON (ranges_options.cmake:19-21). That is both
        # a cross-build disaster and the opposite of header-only.
        # RANGE_V3_PERF and RANGE_V3_HEADER_CHECKS already default OFF but
        # are passed explicitly for the same reason.
        #
        # range-v3 ships no pkg-config file; consumers use the CMake package
        # config under lib/cmake/range-v3/ or add -I$PREFIX/include themselves.
        #
        # install(DIRECTORY include/ DESTINATION include) at line 186 copies
        # the WHOLE include tree - range/, concepts/, meta/, std/ and
        # module.modulemap - which is why this recipe runs upstream's own
        # install rather than copying headers by hand.
        cmake -S . -B build $CMAKE_FLAGS -DRANGE_V3_TESTS=OFF -DRANGE_V3_EXAMPLES=OFF -DRANGE_V3_DOCS=OFF -DRANGE_V3_PERF=OFF -DRANGE_V3_HEADER_CHECKS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
