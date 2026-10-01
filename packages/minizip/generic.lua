require("zlib")
require("minizip@source")

-- BLOCKED. minizip has no buildable form under this project's build-body
-- rules, so the recipe refuses here with a legible message rather than
-- carrying a ./configure invocation that is certain to fail on its first line.
-- This is the same shape packages/lapack/generic.lua uses.
--
-- The blocker is NOT intrinsic to minizip. It is one unsanctioned verb:
--
--   contrib/minizip ships configure.ac (786 bytes) and Makefile.am (818 bytes)
--   but NO generated configure, and no aclocal.m4, no config.h.in and no
--   Makefile.in. The autotools route therefore needs autoreconf (and libtool,
--   because configure.ac:7 calls LT_INIT). autoreconf is a code generator,
--   like the configure it produces, and it is not among AGENTS.md's permitted
--   build-body verbs (cp, ./configure, cmake, make, make install, ninja,
--   touch, find, mkdir, cat-heredocs).
--
-- The alternatives are closed too, not merely unchosen:
--   * contrib/minizip ships no CMakeLists.txt, so there is no cmake path.
--   * contrib/minizip/Makefile (2012-era, hand-written) has NO install target
--     at all -- its only rules are all/miniunz/minizip/test/clean -- and its
--     `all` builds two demo programs against ../../libz.a, so it needs zlib
--     built in place and produces executables, not a staged libminizip.
--
-- Consistency note: packages/cmph/generic.lua:36 does run `autoreconf -fi`,
-- which is the same unsanctioned verb. minizip and cmph cannot both be right.
-- cmph's WILL BUILD is the outlier; see stage1.md for the adjudication.
return recipe({
    build = [[
        echo "minizip: BLOCKED - contrib/minizip ships no generated configure." >&2
        echo "minizip: configure.ac and Makefile.am are present, but configure," >&2
        echo "minizip: aclocal.m4, config.h.in and Makefile.in are not. The" >&2
        echo "minizip: autotools route needs autoreconf, which is not one of" >&2
        echo "minizip: AGENTS.md's permitted build-body verbs." >&2
        echo "minizip: No cmake path and no install target exist as fallbacks." >&2
        echo "minizip: This is a project-rules gap, not a build regression." >&2
        echo "minizip: See packages/minizip/stage1.md. Not building." >&2
        exit 1
    ]]
})