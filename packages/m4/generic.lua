require("m4@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/m4/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        touch doc/m4.1 doc/m4.texi doc/stamp-vti doc/version.texi
        # help2man missing: m4.1 rule regenerates from the binary; make the
        # target newer than its prerequisite so the rule never fires.
        touch -d '+1 day' doc/m4.1
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
