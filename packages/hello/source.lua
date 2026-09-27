return package({
    build = [[
        cp -rf $RECIPEDIR/main.c $OUT
    ]]
})
