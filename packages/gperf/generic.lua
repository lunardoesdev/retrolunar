require("gperf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gperf/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # configure.ac:33 has AC_CONFIG_SUBDIRS([lib src tests doc]), so
        # lib/configure and src/configure are live maintainer targets in
        # their own right, each with its own autoheader rule over its own
        # config.h.in. Sweep them by name rather than chasing the list.
        touch configure src/config.h.in lib/config.h.in
        # The subdirectories have their own generated configure and
        # aclocal.m4; touching configure is cheaper to regenerate than
        # aclocal.m4, but both can re-run from a tarball mtime.
        find . -name 'configure' | xargs touch
        find . -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
        # The release includes these docs; avoid requiring TeX to rebuild them.
        touch doc/gperf.info doc/gperf.pdf doc/gperf.html doc/gperf.1
        make -j1
        make install
    ]]
})
