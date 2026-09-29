require("setuptools@source")

return recipe({
    build = [[
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r $NESTDIR/source/setuptools/* $OUT/lib/python3.14/site-packages/
    ]]
})
