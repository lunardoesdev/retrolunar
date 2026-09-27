require("hello@source")

return recipe({
    build = [[
        cp -rf $NESTDIR/source/hello/* .
        mkdir -p $OUT/bin
        $CC $CFLAGS main.c -o $OUT/bin/hello
    ]]
})
