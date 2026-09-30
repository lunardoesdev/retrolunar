require("wheel@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/wheel/* .
        # Pure Python: copy the package into site-packages. LFS builds a
        # wheel with pip3, which would also add dist-info metadata; we skip
        # that because it needs a host Python, and only the module is used.
        # CPython 3.14's install scheme. packages/python pins 3.14.7, so this
        # is the only site-packages its interpreter searches; a python
        # version bump means updating this line. An earlier version used
        # python3.13, which this prefix's interpreter never searches, so
        # `import wheel` failed at runtime.
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r src/wheel $OUT/lib/python3.14/site-packages/
        cp LICENSE.txt $OUT/lib/python3.14/site-packages/wheel/LICENSE.txt
    ]]
})
