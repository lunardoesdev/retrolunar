require("readline")
require("bc@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bc/* .
        # This custom configure has no --host/--build options.
        # Build tools run on the host; both compilers need C99 mode.
        # Android does not provide the message catalog functions Bc's NLS uses.
        CC="$CC -std=c99" HOSTCC="cc" HOSTCFLAGS="-std=c99" ./configure --prefix="$OUT" --enable-readline --disable-nls
        # The custom configure omits termcap from its static Readline link.
        make -j1 LDFLAGS="$LDFLAGS -lreadline -ltermcap"
        make install
    ]]
})
