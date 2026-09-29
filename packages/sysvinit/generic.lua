require("sysvinit@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/sysvinit/* .
        make
        make install ROOT="$OUT" usrdir=
    ]]
})
