require("perl@native")
require("intltool@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/intltool/* .
        # intltool ships perl scripts, and its configure probes for perl, so the
        # generator side runs under the native perl from $NATIVE_PREFIX/bin
        # (already on PATH via the loader). Its compiled-in @INC names the build
        # staging dir, so PERL5LIB points it at the installed module tree.
        export PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
