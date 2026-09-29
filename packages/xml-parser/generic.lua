require("expat")
require("xml-parser@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xml-parser/* .
        # Blocked: this is an XS module, so the perl that runs Makefile.PL
        # must itself be a target perl. The nest has no perl package, and
        # Perl is blocked in the backlog, so the only perl available is
        # the host x86_64 one, which would emit an x86_64 .so.
        perl Makefile.PL EXPATINCPATH=$PREFIX/include EXPATLIBPATH=$PREFIX/lib
        make
        make install
    ]]
})
