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
        # libglog.pc's Cflags is a genuine upstream packaging defect, on
        # every system, not an Android artifact. libglog.pc.in:11 is a
        # literal `Cflags: -I${includedir}` with no @variable@ in it, so no
        # cmake option reaches it, while CMakeLists.txt:416 makes
        # GLOG_USE_GLOG_EXPORT a PUBLIC compile definition of the target. A
        # find_package(glog) consumer therefore gets it for free through
        # INTERFACE_COMPILE_DEFINITIONS; a pkg-config consumer gets nothing,
        # and the header then hard-fails: logging.h:55-57 includes
        # glog/export.h only under `#if defined(GLOG_USE_GLOG_EXPORT)`, and
        # logging.h:59-61 is `#error <glog/logging.h> was not included
        # correctly` when GLOG_EXPORT or GLOG_NO_EXPORT is undefined. There
        # is no recipe-side alternative: the macro has to reach the consumer
        # as a compile flag, and the .pc Cflags line is the only channel a
        # pkg-config consumer reads.
        #
        # This rewrites the .pc in $OUT, not an upstream source file.
        # AGENTS.md's no-patch rule covers libglog.pc.in and the sources it
        # is generated from; this is a post-install edit of a generated
        # artifact in our own staging directory, on the same lines the loader
        # already rewrites there for the same reason ($OUT to $PREFIX,
        # src/loader.lua:454-468). It is a plain substitution, not a patch,
        # and it is the only route: with no @variable@ in the Cflags line,
        # cmake has nothing to configure. A duplicate Cflags: key would not
        # do either - pkg-config resolves it last-key-wins, which drops the
        # -I rather than adding to it - so the existing line is rewritten.
        #
        # The added text contains no $OUT, so the loader's staged-.pc pass
        # takes its `*)` arm and prints this line verbatim. The rewrite
        # cannot double-apply: cmake --install regenerates the .pc from
        # libglog.pc.in on every build, so the input never already carries
        # the macro.
        awk '{ if ($0 ~ /^Cflags:/) print $0 " -DGLOG_USE_GLOG_EXPORT"; else print }' "$OUT/lib/pkgconfig/libglog.pc" > "$WORK/libglog.pc"
        cp "$WORK/libglog.pc" "$OUT/lib/pkgconfig/libglog.pc"
    ]]
})
