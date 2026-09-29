require("lfs-bootscripts@source")

return recipe({
    build = [[
        # Pure data: the tarball holds the LFS init scripts and the rc
        # symlink table, staged verbatim under $OUT.
        mkdir -p $OUT/etc
        cp -r $NESTDIR/source/lfs-bootscripts/* $OUT/etc/
    ]]
})
