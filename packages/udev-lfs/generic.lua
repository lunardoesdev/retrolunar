require("udev-lfs@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/udev-lfs/* .
        # The tarball ships its own Makefile.lfs, which installs the LFS
        # udev rules, the network rule generators and their docs.
        # DESTDIR is the install root, so it points at $OUT.
        make -f udev-lfs-20230818/Makefile.lfs install DESTDIR=$OUT
    ]]
})
