-- Why this file exists at all, and why there is no android.lua.
--
-- Boost's build system is b2/jam, and b2 is not a library: it is a program
-- that must RUN on the build machine in order to read the Jamfiles and drive
-- anything. Upstream is explicit about this. bootstrap.sh:229 builds the
-- engine with
--     CXX= CXXFLAGS= "$my_dir/tools/build/src/engine/build.sh"
-- having first cleared $CXX and $CXXFLAGS, precisely so the engine is built
-- by the HOST compiler rather than the target compiler. A cross-built b2
-- would be an aarch64-android or x86_64-w64-mingw32 ELF sitting in $PREFIX
-- that could never usefully run here, and running it to find out would be
-- emulation, which AGENTS.md forbids outright.
--
-- So this is the packages/file/ shape, not the packages/mold/ shape:
--   - boost/generic.lua     - the real install, for every target system
--   - boost/clang-native.lua - builds the b2 ENGINE, a host helper
--   - boost/source.lua      - the tarball
-- There is deliberately NO android.lua. Nothing here is Android-specific:
-- the engine build uses $CXX/$CXXFLAGS from whichever system setup is in
-- effect, and the flags on the b2 command line are layout and prefix, not
-- target facts. A file that was a byte-identical copy of generic.lua would
-- be the same defect as the bison/android.lua that was deleted for exactly
-- that reason.
require("boost@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/boost/* .

        # Build the b2 engine. This is upstream's own build script, run the
        # way upstream runs it: engine/build.sh compiles the 65 C++ sources
        # listed at build.sh:432-497 straight into a host executable named
        # b2 (build.sh:513). bootstrap.sh would do this plus a lot we do not
        # want here - it probes for Python and ICU (bootstrap.sh:271-321),
        # and writes a project-config.jam (bootstrap.sh:336-394) that pins
        # prefix/libdir to /usr/local. The engine build is the only part of
        # bootstrap.sh this package needs.
        #
        # $CXX and $CXXFLAGS come from clang-native's setup
        # (packages/clang-native/generic.lua:9, :27) and are the HOST clang,
        # which is what makes the resulting b2 a host binary. -d0 silences
        # b2's own progress output. The build is a single compiler
        # invocation, so it cannot fan out.
        CXX="$CXX" CXXFLAGS="$CXXFLAGS" tools/build/src/engine/build.sh --cxxflags="-O2 -DNDEBUG"
        mkdir -p $OUT/bin
        cp tools/build/src/engine/b2 $OUT/bin/b2
    ]]
})