require("systemd-man-pages@source")

return recipe({
    build = [[
        mkdir -p $OUT/share/man
        cp -r $NESTDIR/source/systemd-man-pages/* $OUT/share/man/
    ]]
})
