require("flit-core@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flit-core/* .
        # Flit-core is pure Python, so installing it is a matter of copying
        # the package into the site-packages tree. LFS builds a wheel with
        # pip3, which would also add dist-info metadata; we skip that
        # because it needs a host Python, and only the module is used.
        mkdir -p $OUT/lib/python3.13/site-packages
        cp -r flit_core $OUT/lib/python3.13/site-packages/
        cp LICENSE $OUT/lib/python3.13/site-packages/flit_core/LICENSE
    ]]
})
