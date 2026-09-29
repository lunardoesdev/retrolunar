require("libtool@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libtool/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # aclocal.m4 depends on the m4/*.m4 set (am__aclocal_m4_deps in
        # Makefile.in:104), and the tarball's mtimes otherwise make make
        # re-run aclocal-1.17, which this prefix does not have - it ships
        # automake 1.18. Touch the whole dependency set, newest last.
        find . -path '*/m4/*.m4' | xargs touch
        touch configure.ac configure config.h.in
        touch aclocal.m4
        # config.status must be touched after aclocal.m4. Otherwise make sees
        # configure as newer, runs `config.status --recheck`, which re-runs
        # configure and resets every timestamp, so the next pass wants to
        # rebuild aclocal.m4 again and asks for aclocal-1.17.
        touch config.status libtool
        make
        make install
    ]]
})
