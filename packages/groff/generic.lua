require("groff@source")

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
        # doc/webpage.ps and doc/grnexmpl.ps are PostScript renderings
        # of the example documents; generating them means running the
        # freshly cross-compiled troff, which cannot execute on the build
        # host. The example sources (doc/pic.ms, doc/me-revisions) are
        # installed, so pre-touch the renderings to skip that step.
        touch doc/webpage.ps doc/grnexmpl.ps
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
