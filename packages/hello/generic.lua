return package({
    build = [[
        $CC $CFLAGS main.c -o $OUT/hello
    ]]
})
