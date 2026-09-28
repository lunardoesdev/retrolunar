require("gperf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gperf/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch configure config.h.in
        # The library subdirectory has its own generated aclocal.m4.
        find . -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
        # The release includes these docs; avoid requiring TeX to rebuild them.
        touch doc/gperf.info doc/gperf.pdf doc/gperf.html doc/gperf.1
        make -j1
        make install
    ]]
})
