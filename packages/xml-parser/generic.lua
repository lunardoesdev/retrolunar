require("expat")
require("xml-parser@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xml-parser/* .
        # XS module: Makefile.PL and xsubpp are build-time generators and are
        # meant to run under a NATIVE perl, from $NATIVE_PREFIX/bin. The XS
        # sources they emit are then compiled by the Android cross-compiler.
        # That is the same shape as gperf@native in packages/bison, so this
        # wants require("perl@native") once such a package exists; the path is
        # taken from the environment rather than hardcoded.
        #
        # Not buildable yet: no perl@native package exists, and a host perl's
        # CORE headers do not compile for Android. See the backlog entry.
        perl Makefile.PL EXPATINCPATH=$PREFIX/include EXPATLIBPATH=$PREFIX/lib
        make
        make install
    ]]
})
