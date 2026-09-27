return recipe({
    build = [[
        cp -rf $RECIPEDIR/main.c $OUT
    ]]
})
