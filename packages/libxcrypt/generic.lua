require("perl@native")
require("libxcrypt@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libxcrypt/* .
        # build-aux/scripts/expand-selected-hashes is a perl script run by
        # configure, and the native perl's compiled-in @INC names the build
        # staging dir, so its core modules are unreachable without this.
        export PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=glibc
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
