return recipe({
    build = [[
        mkdir -p $OUT$PREFIX/hello
        cp -rf $RECIPEDIR/main.c $OUT$PREFIX/hello
    ]]
})
