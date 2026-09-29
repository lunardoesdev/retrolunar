require("iana-etc@source")

return recipe({
    build = [[
        # Pure data: the tarball holds the IANA protocol registry tables.
        mkdir -p $OUT/etc
        cp $NESTDIR/source/iana-etc/services $NESTDIR/source/iana-etc/protocols $OUT/etc/
    ]]
})
