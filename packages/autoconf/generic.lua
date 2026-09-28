require("m4")
require("autoconf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/autoconf/* .
        # The generated scripts embed their data directory; configure with
        # the final prefix, then route make install to the stage directory.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --prefix="$PREFIX"
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 bin/autoconf bin/autoheader bin/autom4te bin/autoreconf bin/autoscan bin/autoupdate bin/ifnames
        make -j1 .version
        # Keep the manuals shipped in the release instead of requiring
        # help2man on the build host.
        touch man/autoconf.1 man/autoheader.1 man/autom4te.1 man/autoreconf.1 man/autoscan.1 man/autoupdate.1 man/ifnames.1
        make -j1
        make -j1 prefix="$OUT" install
    ]]
})
