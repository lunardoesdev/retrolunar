require("wheel@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/wheel/* .
        # Pure Python: copy the package into site-packages. LFS builds a
        # wheel with pip3, which would also add dist-info metadata; we skip
        # that because it needs a host Python, and only the module is used.
        mkdir -p $OUT/lib/python3.13/site-packages
        cp -r src/wheel $OUT/lib/python3.13/site-packages/
        cp LICENSE.txt $OUT/lib/python3.13/site-packages/wheel/LICENSE.txt
    ]]
})
