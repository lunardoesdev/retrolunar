-- re2c is a HOST tool: a lexer generator. Its output is C/C++/Go/Java/...
-- source that gets compiled into some *other* package, so re2c itself has
-- to run on the build machine that runs that package's compiler. A re2c in
-- a target prefix could only generate code for a target nobody compiles
-- here. Consumers should require("re2c@native"), which resolves to this
-- file -- the same shape as packages/bison/generic.lua's gperf@native and
-- packages/libnl-3/generic.lua's flex@native.
require("re2c@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/re2c/* .
        # re2c 4.6 ships both an autotools and a cmake build (configure,
        # configure.ac, Makefile.am, Makefile.in, aclocal.m4, config.h.in are
        # all present alongside CMakeLists.txt). cmake is the one taken here
        # so the toolchain comes from $CMAKE_FLAGS, as the rest of this prefix
        # does.
        #
        # -DRE2C_BUILD_TESTS=OFF is load-bearing. CMakeLists.txt:53 defaults
        # it to "${RE2C_IS_ROOT_PROJECT}", and re2c is the root project, so
        # it defaults ON. The test suite works by running the freshly built
        # re2c over its own input corpus and diffing the output -- on a cross
        # build that means executing a target binary, which this repository
        # forbids outright. CMakeLists.txt:56 also pulls in the test harness
        # whenever this is on.
        #
        # The four RE2C_REBUILD_* options (lexers, parsers, syntax, docs at
        # CMakeLists.txt:23,28,33,34) already default OFF, so nothing
        # regenerates itself with a host re2c; left at their defaults.
        # RE2C_BUILD_BENCHMARKS and RE2C_BUILD_LIBS (CMakeLists.txt:49,35)
        # also default OFF. No DESTDIR: $MESON_FLAGS-style --prefix=$OUT is
        # already inside $CMAKE_FLAGS.
        cmake -S . -B build $CMAKE_FLAGS -DRE2C_BUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
