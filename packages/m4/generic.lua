require("m4@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/m4/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure lib/config.hin
        find . -name 'Makefile.in' | xargs touch
        make -j1 -C lib
        make -j1 -C src
        make -j1 .version
        make -j1 -C doc version.texi
        # Keep the shipped man page; regenerating it would execute the
        # Android m4 binary on the build host.
        touch doc/m4.1
        make -j1
        make install
    ]]
})
