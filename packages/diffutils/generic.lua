require("diffutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/diffutils/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Build the tools first, so the manual pages shipped in the release
        # stay newer than them and are not regenerated with help2man.
        make -j1 -C src
        touch man/cmp.1 man/diff.1 man/diff3.1 man/sdiff.1
        make -j1
        make -j1 install
    ]]
})
