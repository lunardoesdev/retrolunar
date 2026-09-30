require("zlib")
require("giflib@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/giflib/* .
        # giflib ships a plain makefile, not an Autotools one, so there is no
        # configure to run: the variables it reads (PREFIX, CC, CFLAGS,
        # LDFLAGS) are the ones the system already exports. IGRAPHICS and
        # the man pages stay off by default; only the archive and the header
        # are wanted.
        make -j1 CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" PREFIX="$OUT"
        make install-lib install-include PREFIX="$OUT"
    ]]
})
