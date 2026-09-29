require("ninja@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ninja/* .
        # configure.py merges CFLAGS into C++ flags; omit the C-only NDK sysroot include.
        CFLAGS="$CXXFLAGS" python3 configure.py --platform=linux
        ninja -j1
        mkdir -p $OUT/bin
        cp ninja $OUT/bin/ninja
    ]]
})
