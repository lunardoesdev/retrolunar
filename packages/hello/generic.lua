return recipe({
    build = [[
        $CC $CFLAGS main.c -o $OUT/hello
    ]]
})
