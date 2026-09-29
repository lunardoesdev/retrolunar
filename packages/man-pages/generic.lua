require("man-pages@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/man-pages/* .
        # Pure data: the tarball ships pre-formatted roff manuals, so they are
        # staged straight into the man directories.
        mkdir -p $OUT/share/man
        cp -r man $OUT/share/man/
    ]]
})
