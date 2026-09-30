require("glog@source")

-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe. It is generic.lua plus one
-- cache answer, -DANDROID=ON, which is an Android fact and therefore cannot
-- live in the system-neutral fallback; every other line and the .pc rewrite
-- below are the same as generic.lua, whose comments carry the full rationale
-- for the cmake switches and for the staged-.pc edit.
return recipe({
    build = [[
        cp -r $NESTDIR/source/glog/* .
        # glog 0.7.1 is CMake-only: the autotools build was dropped upstream
        # (0.4.0 still shipped configure.ac, 0.6.0 and 0.7.1 do not), and the
        # v0.7.1 release carries no downloadable dist tarball either, so the
        # git tag archive is the only source and CMake is the only build.
        # Static libglog.a, the glog/ headers and libglog.pc. BUILD_TESTING
        # is the switch that matters most: include(CTest) defaults it ON and
        # glog then builds ten host test executables (logging_unittest,
        # symbolize_unittest, stacktrace_unittest and the rest), which is both
        # a cross-link problem and a set of target binaries we must never run.
        # WITH_GFLAGS=OFF: gflags is not in this prefix, and without it glog
        # drops its own command-line flag parsing (GLOG_USE_GFLAGS stays off).
        # WITH_GTEST=OFF and WITH_GMOCK=OFF: GoogleTest is in this prefix, and
        # leaving these on would link the test tree into the library.
        # WITH_PKGCONFIG=ON generates libglog.pc; upstream defaults it OFF.
        # WITH_UNWIND=none is a reproducibility choice, not a capability
        # one. Bionic's sysroot has no unwind.h or libunwind.h at all, so
        # find_package(Unwind) can only ever succeed on clang-native, where
        # it would pick up the HOST's libunwind, compile
        # stacktrace_libunwind-inl.h and bake -lunwind into
        # Libs.private (CMakeLists.txt:435-438) - while every Android family
        # would compile the generic backtrace path. Left at the upstream
        # default the artifact would differ per system. packages/libunwind
        # 1.8.3 exists but is deliberately not a dependency here; if the
        # tree ever wants native libunwind stack traces, that is a
        # per-system recipe, not this generic one.
        # WITH_SYMBOLIZE stays on (upstream default): it is glog's own ELF
        # symbolizer, needs no extra library, and is what makes
        # --symbolize_full stack traces work.
        #
        # -DANDROID=ON is the fix for a real defect in the installed
        # libglog.pc, and it is the smallest one available: glog's own
        # CMakeLists.txt:463-466 already does the right thing under it,
        #   if (ANDROID)
        #     target_link_libraries (glog PRIVATE log)
        #     set (glog_libraries_options_for_static_linking "... -llog")
        #   endif (ANDROID)
        # and it never fires here, because ANDROID is the cache variable
        # cmake derives from CMAKE_SYSTEM_NAME being Android, and our
        # toolchain files deliberately keep set(CMAKE_SYSTEM_NAME Linux)
        # (packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3)
        # to keep cmake out of its own NDK integration. So without this the
        # installed Libs.private is `-pthread` with no -llog, while
        # libglog.a carries one undefined reference, __android_log_write
        # from AlsoErrorWrite (src/utilities.cc, reached from ordinary
        # logging paths), which lives in Bionic's liblog. Every
        # `pkg-config --libs --static libglog` consumer then fails at link
        # with `ld.lld: error: undefined symbol: __android_log_write`. The
        # system-level -llog in the Android systems' LDFLAGS does not help
        # such a consumer: it only reaches consumers that link through this
        # build system. Setting the variable by hand is honest - we ARE
        # cross-compiling for Android, the toolchain file only declines to
        # tell cmake so - and it is not a patch: it is a cache answer to a
        # question upstream already asks, and it also repairs the exported
        # CMake target, which then carries $<LINK_ONLY:log> for
        # find_package(glog) consumers.
        #
        # It changes nothing about the compiled library: the archive built
        # with and without it is byte-identical on this system (both 559844
        # bytes, `cmp` clean), because the branch only adds link metadata.
        # The one cmake-internal effect worth naming is Compiler/Clang.cmake:84,
        # which would set CMAKE_<lang>_LINK_OPTIONS_IPO to -fuse-ld=gold
        # because CMAKE_ANDROID_NDK_VERSION is unset; glog does not enable
        # IPO, so that variable is never read.
        cmake -S . -B build $CMAKE_FLAGS -DANDROID=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DWITH_GFLAGS=OFF -DWITH_GTEST=OFF -DWITH_GMOCK=OFF -DWITH_PKGCONFIG=ON -DWITH_UNWIND=none
        cmake --build build --parallel 1
        cmake --install build
        # Same staged-.pc edit as generic.lua, for the same reason (there:
        # libglog.pc.in's Cflags line has no @variable@, so cmake cannot put
        # GLOG_USE_GLOG_EXPORT there, and a pkg-config consumer without it
        # hits logging.h's #error). It rewrites the generated .pc in $OUT,
        # our own staging directory, not an upstream source file.
        awk '{ if ($0 ~ /^Cflags:/) print $0 " -DGLOG_USE_GLOG_EXPORT"; else print }' "$OUT/lib/pkgconfig/libglog.pc" > "$WORK/libglog.pc"
        cp "$WORK/libglog.pc" "$OUT/lib/pkgconfig/libglog.pc"
    ]]
})
