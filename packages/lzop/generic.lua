-- lzop needs the LZO HEADERS and the LZO LIBRARY, both hard errors:
-- configure.ac:116-118 aborts with "LZO header files not found" when no
-- lzoconf.h/lzo1x.h is reachable, and configure.ac:145-150 then does
-- AC_CHECK_LIB(lzo, __lzo_init2) / AC_CHECK_LIB(lzo2, __lzo_init_v2),
-- each with AC_MSG_ERROR as its failure action. There is no --without-lzo.
require("lzo")
require("lzop@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lzop/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # The config template is config.hin, not config.h.in: configure.ac:79
        # reads AC_CONFIG_HEADERS([config.h:config.hin]) and the shipped file
        # is config.hin (13960 bytes, listed in the 126-entry tarball index).
        touch aclocal.m4 configure config.hin
        # Single Makefile: configure.ac:201 AC_CONFIG_FILES([Makefile]) and
        # there is no AC_CONFIG_SUBDIRS, so no sub-tree Makefile.in exists.
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
