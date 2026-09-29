require("tcl-docs@source")

return recipe({
    build = [[
        mkdir -p $OUT/share/doc/tcl8.6.18
        cp -r $NESTDIR/source/tcl-docs/* $OUT/share/doc/tcl8.6.18/
    ]]
})
