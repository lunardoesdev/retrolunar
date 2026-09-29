require("lz4@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lz4/* .
        # The lib/ Makefile honours PREFIX and BUILD_SHARED/LIBDIR, which is
        # how lz4 expects to be installed into a staged prefix.
        make -C lib PREFIX="$OUT" BUILD_SHARED=no BUILD_STATIC=yes
        make -C lib PREFIX="$OUT" BUILD_SHARED=no BUILD_STATIC=yes install
        make -C programs PREFIX="$OUT"
        make -C programs PREFIX="$OUT" install
    ]]
})
