require("p7zip@source")

-- p7zip 16.02 has no cmake, no meson and no autotools. It is a hand-written GNU
-- make tree: `makefile` (targets) -> `makefile.common` -> `makefile.machine`
-- (per-platform flags).
--
-- `7za` is the standalone bundle (`makefile:19`: `7za: common` -> `CPP/7zip/
-- Bundles/Alone`). It is the right target: `all` (makefile:21) also builds the
-- SFX self-extractor, and `7z`/`Client7z`/`7zFM` (makefile:24-56) pull in the
-- GTK GUI. `7za` needs only the compiler.
--
-- No install step: upstream's `install:` target (makefile.common:115) shells out
-- to `./install.sh`, which runs `strip` and `sed` and writes wrapper scripts.
-- Both are outside this project's build-body rules, so the binary is copied
-- straight into $OUT instead.
return recipe({
    build = [[
        cp -r $NESTDIR/source/p7zip/* .
        # makefile.machine is a fragment, not an entry point: the top-level
        # `makefile` includes makefile.common, which includes it (line 15).
        # makefile.machine:14-15 hardcodes CC=gcc/CXX=g++, so the system's
        # compilers are passed as make variables, which override them. The
        # system's flags reach the build through $(ALLFLAGS).
        make CC="$CC" CXX="$CXX" 7za
        mkdir -p $OUT/bin
        cp bin/7za $OUT/bin/7za
    ]]
})