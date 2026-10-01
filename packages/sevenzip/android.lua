require("sevenzip@source")

-- Android-only switch, for one reason: Bionic has no libpthread.
--
-- 7zip_gcc.mak:164-165 hardcodes `LIB2 = -lpthread` (then `-lpthread -ldl`) for
-- every non-mingw target, and 7zip_gcc.mak:254 folds $(LIB2) into the link line,
-- so the final link really does ask for it. A probe against the NDK r28 clang
-- wrappers confirms it cannot be satisfied:
--
--   $ aarch64-linux-android35-clang t.c -lpthread -o t.out
--   ld.lld: error: unable to find library -lpthread
--
-- `-ldl` *is* present in the Bionic sysroot, so only -lpthread is the problem.
-- Bionic folds the pthread API into libc, so the correct Android link line is
-- the one without it. Passing LIB2= on the make command line overrides the
-- assignment at 7zip_gcc.mak:164 without editing upstream's file; a dry run
-- confirms the resulting link line contains no -lpthread.
--
-- This belongs in android.lua rather than generic.lua because it is a fact
-- about Bionic, not about 7-Zip: the same -lpthread is correct and required on
-- both glibc systems.
return recipe({
    build = [[
        cp -r $NESTDIR/source/sevenzip/* .
        # Same command as generic.lua, plus LIB2= to drop -lpthread. See the
        # comment above for the probe output that makes this load-bearing.
        make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc -j1 CC="$CC" CXX="$CXX" CFLAGS_BASE2="$CFLAGS" CXXFLAGS_BASE2="$CXXFLAGS" CFLAGS_WARN_WALL="-Wall -Wextra" LIB2=""
        mkdir -p $OUT/bin
        cp CPP/7zip/Bundles/Alone2/_o/7zz $OUT/bin/7zz
    ]]
})