require("sevenzip@source")

-- 7-Zip 26.03 ships no cmake, no meson and no autotools. Its build system is
-- Windows nmake (Build.mak, `!IFNDEF`) plus a set of GNU-make files whose
-- documented entry point is `cd CPP/7zip/Bundles/Alone2 && make -f makefile.gcc`
-- (readme.txt:138-144). `Alone2` builds the full `7zz` binary.
--
-- Why these make variables are passed explicitly:
--   CC/CXX  7zip_gcc.mak uses $(CC)/$(CXX) with no default of its own, so
--           without these a cross build silently compiles with the host cc.
--   CFLAGS_BASE2 / CXXFLAGS_BASE2
--           7zip_gcc.mak:172 and :213 assemble the compile flags from scratch
--           ($(MY_ARCH_2) $(LOCAL_FLAGS) $(CFLAGS_BASE2) $(CFLAGS_BASE) ...) and
--           never reference $CFLAGS/$CXXFLAGS. These two variables are read but
--           never assigned anywhere in the tree, so they are the clean seam for
--           handing over the system's search paths without clobbering upstream's
--           own -O2/-DNDEBUG/-D_FILE_OFFSET_BITS=64. Appending rather than
--           overriding LOCAL_FLAGS, which Alone2/makefile.gcc:43 sets to a
--           value that selects -DZ7_ST/-DZ7_DEVICE_FILE.
--   CFLAGS_WARN_WALL
--           7zip_gcc.mak:27 hardcodes `-Werror -Wall -Wextra`, which turns any
--           warning in a 2026 release compiled by a 2026 clang into a build
--           failure. -Wall -Wextra are kept; only -Werror is dropped. This is
--           why it is passed as a command-line variable: a command-line
--           assignment overrides the makefile's, and upstream's own file is
--           never edited.
--
-- $LDFLAGS needs no help: 7zip_gcc.mak:254 already folds $(LDFLAGS) into the
-- link line, so the system's link flags arrive on their own.
--
-- There is no install target anywhere in the tree, so the binary is copied
-- into $OUT directly (the reviewed recipe had no publish step at all, so it
-- would have merged an empty tree).
return recipe({
    build = [[
        cp -r $NESTDIR/source/sevenzip/* .
        # upstream's documented entry point (readme.txt:138-144), run from the
        # bundle directory that holds makefile.gcc. `make` already defaults to
        # serial; -j1 spells that out.
        make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc -j1 CC="$CC" CXX="$CXX" CFLAGS_BASE2="$CFLAGS" CXXFLAGS_BASE2="$CXXFLAGS" CFLAGS_WARN_WALL="-Wall -Wextra"
        mkdir -p $OUT/bin
        cp CPP/7zip/Bundles/Alone2/_o/7zz $OUT/bin/7zz
    ]]
})