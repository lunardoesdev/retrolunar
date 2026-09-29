require("man-pages@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/man-pages/* .
        # Pure data: the tarball ships pre-formatted roff manuals.
        #
        # Its top-level man1/man3/... entries are symlinks into man/, but the
        # rest of the prefix installs real manN directories, so the section
        # directories are copied out of man/ as real directories here. Copying
        # the symlinks themselves would collide with those real directories on
        # publish.
        mkdir -p $OUT/share/man
        for _s in man/*; do
            cp -r "$_s" "$OUT/share/man/"
        done
    ]]
})
