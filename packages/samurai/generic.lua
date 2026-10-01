-- samurai is a HOST tool: a ninja-compatible build front-end. Its whole job
-- is to read build.ninja and spawn compilers, so it has to run on the
-- machine that owns those compilers. A samurai in a target prefix would
-- drive a target compiler that nobody has, and nothing in the prefix would
-- use it. Consumers should require("samurai@native"), which resolves to this
-- file, exactly as packages/bison/generic.lua does for gperf@native.
--
-- The installed program is named `samu`, not `samurai` -- see stage1.md for
-- why, and for why the separate `samu` backlog entry is not a second
-- package.
require("samurai@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/samurai/* .
        # A hand-written `.POSIX` makefile: no configure, no autotools, no
        # cmake, no meson. It reads the toolchain from the environment --
        # Makefile:42 compiles with `$(CC) $(ALL_CFLAGS)` and Makefile:45
        # links with `$(CC) $(LDFLAGS)`, neither of which hard-assigns a
        # compiler the way libcap's Make.Rules does -- so the system's $CC,
        # $CFLAGS and $LDFLAGS are picked up as they are.
        #
        # Makefile:8 appends `-std=c99` to $(CFLAGS) and the Makefile puts it
        # last, so the build is strict ISO C99 whatever the system asked for.
        # That is fine: build.c:1 and os-posix.c:1 both define
        # _POSIX_C_SOURCE 200809L before any include, which is what keeps
        # <spawn.h> and posix_spawn declared under -std=c99.
        #
        # Makefile:9 hardcodes `LDLIBS=-lrt` for clock_gettime(CLOCK_MONOTONIC)
        # at build.c:240,247,589. glibc and Bionic both provide it; mingw-w64
        # does not, which is the one platform wall. See stage1.md.
        #
        # `make` already defaults to serial (bare `make` reports MAKEFLAGS=[]),
        # so the build never fans out.
        make
        # Makefile:5-7 derive BINDIR/MANDIR from PREFIX, and Makefile:50-53
        # mkdir -p them under $(DESTDIR). Passing PREFIX=$OUT is therefore
        # enough; DESTDIR stays unset so nothing is nested twice.
        make install PREFIX="$OUT"
    ]]
})
