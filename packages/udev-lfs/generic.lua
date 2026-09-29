require("udev-lfs@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/udev-lfs/. .
        # Pure data: the tarball holds the LFS udev rules, the network rule
        # generators and their docs, all at the top level of the tree.
        #
        # Its own Makefile.lfs is not used: it installs from a versioned
        # subdirectory (udev-lfs-20230818/*.rules), but the release tarball is
        # unpacked flat, so that path does not exist.
        mkdir -p $OUT/lib/udev/rules.d
        mkdir -p $OUT/lib/udev/rules.d/network
        mkdir -p $OUT/usr/share/doc/udev-20230818
        cp *.rules $OUT/lib/udev/rules.d/
        cp *.txt $OUT/usr/share/doc/udev-20230818/
        cp init-net-rules.sh rule_generator.functions $OUT/usr/share/doc/udev-20230818/
        # The rule generators are plain shell scripts, so install them as such.
        mkdir -p $OUT/usr/share/udev
        cp write_cd_rules write_net_rules $OUT/usr/share/udev/
    ]]
})
