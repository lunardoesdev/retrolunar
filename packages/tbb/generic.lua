require("tbb@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tbb/* .
        # oneTBB is a real compiled library (libtbb, libtbbmalloc,
        # libtbbmalloc_proxy), so unlike the header-only packages this build
        # does compile target code.
        #
        # TBB_TEST defaults ON (CMakeLists.txt:114) and add_subdirectory(test)
        # at :350 builds the whole doctest suite as target executables. On a
        # cross build those cannot be run here and must never be, so it is off.
        # TBB_EXAMPLES (:115) and TBB_FUZZ_TESTING (:127) already default OFF.
        #
        # BUILD_SHARED_LIBS=OFF: this prefix is static, as everywhere else in
        # this tree. It also selects the static path in oneTBB's own build:
        # add_subdirectory(src/tbbbind) at :308-311 is skipped, because
        # tbbbind is only built for shared libraries.
        #
        # TBB_STRICT defaults ON (CMakeLists.txt:116), which turns on -Werror
        # through TBB_WARNING_LEVEL (cmake/compilers/Clang.cmake:58). oneTBB's
        # documented compiler support tops out at Clang 13 / GCC 12
        # (SYSTEM_REQUIREMENTS.md:71-73) and every compiler here is newer, so
        # -Werror would fail the build on warnings upstream has never seen.
        # The warning level itself is unchanged; only -Werror is dropped.
        #
        # TBB_ENABLE_IPO defaults ON (:125). It is guarded by
        # "NOT ANDROID_PLATFORM" at :275, but our toolchain files deliberately
        # set CMAKE_SYSTEM_NAME to Linux, so ANDROID_PLATFORM is never set and
        # the guard does not fire on Android. Upstream's own comment at :272-273
        # says LTO on Android trips an NDK bug ("argument unused during
        # compilation: -Wa,--noexecstack"), so IPO is off everywhere rather
        # than needing a per-Android override.
        #
        # TBB_DISABLE_HWLOC_AUTOMATIC_SEARCH defaults to ${CMAKE_CROSSCOMPILING}
        # (:124), which is TRUE on every Android and mingw system here, so the
        # pkg-config hwloc search at cmake/hwloc_detection.cmake:58-71 does not
        # run and no host hwloc leaks in. On clang-native it does run, but
        # PKG_CONFIG_PATH is empty in that system and hwloc is not in this
        # prefix, so the search finds nothing and the build proceeds.
        #
        # TBB_INSTALL stays ON (:128); the install rules at :313-350 and
        # add_subdirectory(cmake/post_install) at :414 depend on it.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DTBB_TEST=OFF -DTBB_STRICT=OFF -DTBB_ENABLE_IPO=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
