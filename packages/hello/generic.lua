require("hello@source")

return recipe({
    build = [[
        cp -rf $NESTDIR/source/hello/* .
        mkdir -p $OUT$PREFIX/bin
        $CC $CFLAGS main.c -o $OUT$PREFIX/bin/hello
    ]]
})
