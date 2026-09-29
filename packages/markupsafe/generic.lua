require("markupsafe@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/markupsafe/* .
        # Pure Python: copy the package into site-packages. The optional
        # _speedups C accelerator is not built (LFS uses pip3 to compile
        # it); the module falls back to its _native.py implementation.
        # No dist-info either, for the same reason as flit-core.
        mkdir -p $OUT/lib/python3.13/site-packages
        cp -r src/markupsafe $OUT/lib/python3.13/site-packages/
        cp LICENSE.txt $OUT/lib/python3.13/site-packages/markupsafe/LICENSE.txt
    ]]
})
