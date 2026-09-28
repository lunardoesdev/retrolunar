require("readline")
require("bc@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bc/* .
        # Bc uses a custom configure script and requires C99.
        CC="$CC -std=c99" ./configure --prefix="$OUT" --enable-readline
        # The custom configure omits termcap from its static Readline link.
        make -j1 LDFLAGS="$LDFLAGS -lreadline -ltermcap"
        make install
    ]]
})
