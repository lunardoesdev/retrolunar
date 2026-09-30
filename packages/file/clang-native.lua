-- The native build of this same 5.46 source, and the reason it is a separate
-- file rather than a require() inside generic.lua.
--
-- Cross-building file needs a `file` on PATH that reports exactly
-- PACKAGE_VERSION: magic/Makefile.am:377-384 hard-fails otherwise, and the
-- build host carries file-5.48. Under IS_CROSS_COMPILE, upstream's
-- FILE_COMPILE is a bare PATH lookup (magic/Makefile.am:366-371), so that
-- PATH `file` is the one that runs. This recipe puts a real 5.46 in
-- $NATIVE_PREFIX/bin, which the loader prepends to PATH
-- (src/loader.lua:412-415), so the check passes by construction.
--
-- Why not just require("file@native") from generic.lua? Because @native is
-- clang-native, and with no packages/file/clang-native.lua the loader falls
-- back to packages/file/generic.lua itself (src/loader.lua:199-201), so the
-- recipe requires itself. src/loader.lua has no module cache and no cycle
-- guard, so that is an unconditional `C stack overflow` at loader.lua:104
-- rather than the duplicate-key error at :166. This file breaks the
-- recursion by being a genuinely different recipe.
--
-- Note for a native build, and do not "fix" it: IS_CROSS_COMPILE is false
-- here, so FILE_COMPILE becomes $(top_builddir)/src/file${EXEEXT} and the
-- build RUNS the file it has just built. That is a host x86_64 executable on
-- this x86_64 build host, which is ordinary and legal. The repository's ban
-- is on running a *target* binary, which is a different thing and does not
-- arise on this path.
require("file@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/file/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Native, so magic/Makefile.am uses $(top_builddir)/src/file and runs
        # it - a host binary, which is fine here. See the note at the top.
        make -j1
        make -j1 install
    ]]
})
