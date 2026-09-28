require("tcl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tcl/* .
        # Tcl's configure script lives in unix/ but accepts being run from
        # the source root; the build then happens in this directory.
        ./unix/configure $AUTOCONF_CONFIGURE_FLAGS --mandir="$OUT/share/man" --disable-rpath
        make -j1
        make -j1 install
        # Expect needs Tcl's private headers.
        make -j1 install-private-headers
    ]]
})
