require("ninja@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ninja/* .
        # Bootstrap with host tools, then rebuild target objects with $CC.
        # configure.py only writes build.ninja; pass cross flags via env.
        python3 configure.py --bootstrap
        mkdir -p $OUT/bin
        cp ninja $OUT/bin/
    ]]
})
