require("man-pages@source")

return recipe({
    build = [[
        # Pure data: pre-formatted roff sources, installed as-is the
        # same way the systemd man page tarball is staged.
        mkdir -p $OUT/share/man
        cp -r $NESTDIR/source/man-pages/* $OUT/share/man/
    ]]
})
