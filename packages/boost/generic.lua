require("boost@native")
require("boost@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/boost/* .

        # Boost 1.92.0 ships b2/jam, not cmake and not meson. There is no
        # ./configure and no CMakeLists.txt at the top level.
        #
        # THE BUILD TOOL IS NATIVE, which is why this file requires
        # boost@native rather than compiling b2 itself. The `b2` executable
        # is not a library: it is the program that reads the Jamfiles and
        # then RUNS on this machine to drive the build. bootstrap.sh:229
        # builds it as
        #     CXX= CXXFLAGS= "$my_dir/tools/build/src/engine/build.sh"
        # i.e. upstream deliberately clears $CXX and $CXXFLAGS so the engine
        # is built with the host compiler, not the target one. Building it
        # from this recipe instead would hand us an aarch64-android or
        # x86_64-w64-mingw32 b2 sitting in $PREFIX/bin that could never run
        # here, and running it to find out would be emulation, which
        # AGENTS.md forbids outright. boost/clang-native.lua therefore
        # builds the engine once with clang-native's $CXX and installs it as
        # $NATIVE_PREFIX/bin/b2, which the loader puts first on PATH
        # (src/loader.lua:413), so the bare `b2` below is the host one.
        #
        # WHY HEADERS ONLY. topackage.md:106-108 requires a serial build
        # with peak memory under 2 GB. A full Boost build compiles the
        # ~50 libraries that have a build/Jamfile and is many hours of work;
        # it is not what this package is for. The consumer that makes this
        # package a hard gate is CGAL, which needs headers plus a package
        # config and nothing else (see stage1.md). The upstream target for
        # exactly that is libs/headers/build//install - libs/headers/
        # README.md:3 says so in as many words: "This is a "fake" library
        # that installs the Boost headers on `b2 libs/headers/build//install`".
        # It is `b2 headers` at the top level that does NOT install anything:
        # Jamroot:356 makes `headers` a notfile target whose action is
        # @do-nothing (Jamroot:344), so it is a build-graph node and not an
        # install step.
        #
        # NOTHING IS COMPILED for the libraries. libs/headers/build/Jamfile
        # globs the header tree (path.glob-tree over $(BOOST_ROOT)/boost for
        # *.hpp *.ipp *.h *.inc, plus boost/compatibility/cpp_c_headers/c*)
        # and hands the files to b2's `install` rule; the cmake package files
        # come from `make` rules whose generating-rule is text emission. No
        # lib target is built, so no archive is produced and no ABI-level
        # question arises. -d0 keeps the graph chatter out of the log.
        b2 -d0 libs/headers/build//install --prefix="$OUT" --layout=system
    ]]
})