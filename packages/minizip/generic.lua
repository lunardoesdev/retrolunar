require("zlib")
require("minizip@source")

-- contrib/minizip ships configure.ac and Makefile.am but NO generated
-- configure, so the autotools path needs autoreconf -- not an allowed
-- build-body verb. The alternative is contrib/minizip/Makefile, a 2012-era
-- hand-written makefile whose `all` target builds only the two demo programs
-- against ../../libz.a. It installs nothing (no install target; `clean` is the
-- only other rule), needs zlib built in-place above it, and links a target
-- binary -- so it cannot produce a staged libminizip.
--
-- The recipe below is therefore upstream's autotools route, which is the only
-- one that installs a library, written in the exact form the diagnosis calls
-- for: it is what the reviewer needs to see to confirm that autoreconf is the
-- load-bearing missing step. Against this project it stops immediately, because
-- there is no ./configure to run. See stage1.md: every system is
-- WILL NOT BUILD for that reason.
return recipe({
    build = [[
        cp -r $NESTDIR/source/minizip/contrib/minizip/* .
        # No configure ships (contrib/minizip/configure.ac exists, the
        # generated script does not), so this cannot run as-is: autoreconf is
        # not one of the allowed build-body verbs. Recorded, not worked around.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-demos
        make -j1
        make install
    ]]
})