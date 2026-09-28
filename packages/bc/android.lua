require("readline")
require("bc@source")

return {
    build = [[
        cp -r $NESTDIR/source/bc/* .
        # Bc's generators run on the host, while the main compiler targets Android.
        # Android does not provide the message catalog functions Bc's NLS uses.
        CC="$CC -std=c99" HOSTCC="cc" HOSTCFLAGS="-std=c99" ./configure --prefix="$OUT" --enable-readline --disable-nls
        # The custom configure omits termcap from its static Readline link.
        make -j1 LDFLAGS="$LDFLAGS -lreadline -ltermcap"
        make install
    ]]
}
