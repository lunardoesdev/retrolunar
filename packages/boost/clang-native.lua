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
        # WINDRES must NOT be in this command's environment. The engine
        # build.sh:502-511 asks $CXX -dumpmachine, and the answer decides
        # whether it embeds a Windows manifest by running windres on
        # res.rc and linking the result. It finds $WINDRES FROM THE
        # ENVIRONMENT -- there is no --windres flag -- and the cross
        # systems export one (x86_64-mingw/generic.lua:19 exports
        # WINDRES=x86_64-w64-mingw32-windres). When this block runs inside a
        # build script that has already exported that, the HOST engine gets
        # a TARGET resource object linked into it and dies with
        #     res.o:(.rsrc+0x48): dangerous relocation:
        #         R_AMD64_IMAGEBASE with __ImageBase undefined
        # because a PE resource section cannot go into an ELF executable.
        #
        # The probe keys on $CXX -dumpmachine, which here answers
        # x86_64_64-pc-linux-gnu, so an empty WINDRES is enough to make the
        # branch not fire at all -- and the extra belt, which is what
        # upstream itself honours, is B2_DONT_EMBED_MANIFEST. Clearing
        # both means the outcome no longer depends on what the surrounding
        # build script happened to export.
        WINDRES= B2_DONT_EMBED_MANIFEST=1 \
            CXX="$CXX" CXXFLAGS="$CXXFLAGS" tools/build/src/engine/build.sh --cxxflags="-O2 -DNDEBUG"
        mkdir -p $OUT/bin
        cp tools/build/src/engine/b2 $OUT/bin/b2
    ]]
})