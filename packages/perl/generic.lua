require("perl@source")

return recipe({
    build = [[
        # The leading dot matters: perl's MANIFEST lists dotfiles such as
        # .dir-locals.el and .editorconfig, and Configure aborts with
        # "THIS PACKAGE SEEMS TO BE INCOMPLETE" when they are missing.
        cp -r $NESTDIR/source/perl/. .
        # perl's Configure is not autoconf: it does not read CC, CFLAGS,
        # CPPFLAGS or LDFLAGS from the environment, and $AUTOCONF_CONFIGURE_FLAGS
        # does not apply to it either. Every setting therefore has to be passed
        # explicitly as a -D option, which is why the system's exported $CC,
        # $CPPFLAGS and $LDFLAGS are forwarded by hand below.
        #
        # BUILD_ZLIB/BUILD_BZIP2 off makes perl link the zlib and bzip2 already
        # in $PREFIX instead of building private copies of them.
        #
        # perl bakes absolute paths for its library search paths and for
        # libperl.so's RUNPATH into the binary, and $OUT is a per-build staging
        # directory that is deleted once the package is published, so a perl
        # built with -Duseshrplib cannot start afterwards: it looks for
        # libperl.so and its modules under the vanished $OUT. Installing
        # privlib/archlib straight into $PREFIX does not help either, because
        # those paths are still absolute and would name this checkout.
        #
        # Building a static perl avoids the problem: without -Duseshrplib the
        # interpreter carries its own copy of the interpreter core and only
        # the module search path remains, which PERL5LIB can correct at run
        # time for packages that need it.
        #
        # Use a fixed libdir layout so downstream recipes can refer to it.
        export BUILD_ZLIB=False
        export BUILD_BZIP2=0
        sh Configure -des \
            -Dcc="$CC" \
            -Doptimize="-O2 -fPIC" \
            -Dcppflags="$CPPFLAGS" \
            -Dldflags="$LDFLAGS" \
            -Dprefix=$OUT \
            -Dvendorprefix=$OUT \
            -Dprivlib=$OUT/lib/perl5/5.44/core_perl \
            -Darchlib=$OUT/lib/perl5/5.44/core_perl \
            -Dsitelib=$OUT/lib/perl5/5.44/site_perl \
            -Dsitearch=$OUT/lib/perl5/5.44/site_perl \
            -Dvendorlib=$OUT/lib/perl5/5.44/vendor_perl \
            -Dvendorarch=$OUT/lib/perl5/5.44/vendor_perl \
            -Dman1dir=$OUT/share/man/man1 \
            -Dman3dir=$OUT/share/man/man3 \
            -Dusethreads
        make
        make install
    ]]
})
