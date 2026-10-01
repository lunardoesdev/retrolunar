require("libxml2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libxml2/* .
        # --without-python / --without-docs: see generic.lua.
        #
        # --without-iconv is a mingw fact, not an Android one. mingw-w64
        # ships no iconv.h at all, so libxml2's iconv probe
        # (configure.ac:860) cannot even compile, the -liconv fallback
        # (configure.ac:866) has no library either, and configure aborts
        # with "libiconv not found" (configure.ac:878-880). The built-in
        # ISO-8859-X tables stay in place (--with-iso8859x, default on).
        ./configure $AUTOCONF_CONFIGURE_FLAGS --without-python --without-docs --without-iconv
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})