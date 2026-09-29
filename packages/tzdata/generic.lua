require("tzdata@source")

return recipe({
    build = [[
        # Pure data: the compiled zoneinfo database plus the tzdata.zi
        # and leap-second files, staged verbatim under $OUT.
        mkdir -p $OUT/usr/share/zoneinfo
        cp -r $NESTDIR/source/tzdata/* $OUT/usr/share/zoneinfo/
    ]]
})
