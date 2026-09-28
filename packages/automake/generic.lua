require("autoconf")
require("automake@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/automake/* .
        # The Perl scripts embed their module directory; stage install separately.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --prefix="$PREFIX"
        # Keep the release's generated version macro and aclocal.m4 current.
        touch m4/amversion.m4 aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 prefix="$OUT" install
    ]]
})
