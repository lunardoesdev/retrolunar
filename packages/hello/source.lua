return recipe({
    build = [[
        mkdir -p $OUT/hello
        cp -rf $RECIPEDIR/main.c $OUT/hello
    ]]
})
