require("packaging@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/packaging/* .
        # Packaging is pure Python; install its module for the target Python 3.14.
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r src/packaging $OUT/lib/python3.14/site-packages/
        cp LICENSE LICENSE.APACHE LICENSE.BSD $OUT/lib/python3.14/site-packages/packaging/
    ]]
})
