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
        # perl bakes absolute paths for its module search path into the
        # binary, and it has no relocation support for them. $OUT is a
        # per-build staging directory that is deleted once the package is
        # published, so pointing the library paths at $OUT leaves the
        # installed perl unable to find its own core modules - every consumer
        # then needs PERL5LIB to work around it.
        #
        # The install target stays $OUT, but the library search paths
        # (privlib/archlib/sitelib/...) name $PREFIX, which is exactly where
        # the emitter publishes them, so the resulting perl is self-consistent
        # and needs no PERL5LIB. The program prefix stays $OUT for the same
        # reason: the binaries are staged and then copied verbatim.
        # Skip perl's own build-time zlib/bzip2 linkage: the modules it
        # builds with the *host* toolchain must not link target libraries
        # out of $PREFIX. Both are in this prefix, so the target perl still
        # gets working zlib and bzip2 from its runtime search path.
        export BUILD_ZLIB=False
        export BUILD_BZIP2=0
        sh Configure -des \
            -Dcc="$CC" \
            -Doptimize="-O2 -fPIC" \
            -Dcppflags="$CPPFLAGS" \
            -Dldflags="$LDFLAGS" \
            -Dprefix=$OUT \
            -Dvendorprefix=$OUT \
            -Dprivlib=$PREFIX/lib/perl5/5.44/core_perl \
            -Darchlib=$PREFIX/lib/perl5/5.44/core_perl \
            -Dsitelib=$PREFIX/lib/perl5/5.44/site_perl \
            -Dsitearch=$PREFIX/lib/perl5/5.44/site_perl \
            -Dvendorlib=$PREFIX/lib/perl5/5.44/vendor_perl \
            -Dvendorarch=$PREFIX/lib/perl5/5.44/vendor_perl \
            -Dman1dir=$OUT/share/man/man1 \
            -Dman3dir=$OUT/share/man/man3 \
            -Dusethreads
        make -j1
        make install
    ]]
})
