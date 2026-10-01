require("sevenzip@source")

-- 7-Zip 26.03 ships no cmake, no meson and no autotools: its build system is
-- Windows nmake (`Build.mak`, `!IFNDEF`) plus a set of GNU-make files whose
-- documented entry point is `cd CPP/7zip/Bundles/Alone2 && make -f makefile.gcc`
-- (readme.txt:138-144). Neither path works from the release tarball here, for
-- the reason recorded in stage1.md: the tarball root is the contents of
-- upstream's CPP/, so the bundle makefile's `../../../..`-relative source
-- references (e.g. `7zip/Bundles/Alone2/makefile.gcc` -> `../../../../C/7zBuf2.c`)
-- resolve outside the unpacked tree.
--
-- The recipe below is the upstream-documented GNU-make invocation, written so it
-- is correct for a checkout that still has its CPP/ prefix. Against the release
-- tarball it stops at "No rule to make target '../../../../C/7zBuf2.c'". See
-- stage1.md: every system is WILL NOT BUILD for that reason.
return recipe({
    build = [[
        cp -r $NESTDIR/source/sevenzip/* .
        # upstream's own documented entry point: run make from the bundle
        # directory that holds makefile.gcc (readme.txt:138-144).
        make -C 7zip/Bundles/Alone2 -f makefile.gcc
    ]]
})