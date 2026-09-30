require("groff@source")

-- Known blocker on every cross system: groff renders its own manual and
-- its example documents with the groff it has just built
-- (Makefile.am:497, GROFFBIN = $(abs_top_builddir)/groff, used by
-- doc/doc.am:39 DOC_GROFF in the rules at doc/doc.am:173-174 and
-- doc/doc.am:392-397). `make install` wants those rendered files
-- (doc/doc.am:130, :139, :178), so the build cannot finish without
-- executing an aarch64 binary on the x86_64 build host.
return recipe({
    build = [[
        cp -r $NESTDIR/source/groff/* .
        # PAGE is the default paper size baked into the troff device
        # drivers; LFS uses the US letter size. It is a groff-specific
        # build variable, not a toolchain flag.
        PAGE=letter ./configure $AUTOCONF_CONFIGURE_FLAGS
        # doc/gnu.eps ships in the release tarball; only the Makefile
        # rule that would regenerate it from doc/gnu.xpm needs the
        # netpbm tools (xpmtoppm/pnmtops), which are not in the nest.
        # Refresh the timestamp so the shipped file is used as-is.
        touch doc/gnu.eps
        touch aclocal.m4 configure src/include/config.hin
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
