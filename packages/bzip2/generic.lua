require("bzip2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bzip2/* .
        make CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-O2 -fPIC" -j$(nproc 2>/dev/null || echo 4) libbz2.a
        mkdir -p $OUT/include $OUT/lib $OUT/lib/pkgconfig
        cp bzlib.h $OUT/include/
        cp libbz2.a $OUT/lib/
    ]]
})
