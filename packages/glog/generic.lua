require("glog@source")

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
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DWITH_GFLAGS=OFF -DWITH_GTEST=OFF -DWITH_GMOCK=OFF -DWITH_PKGCONFIG=ON -DWITH_UNWIND=none
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
