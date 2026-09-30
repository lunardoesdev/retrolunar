require("gmp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gmp/* .
        # No --docdir: upstream's default already lands under $OUT, and
        # pinning a version here would go stale on a bump.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-cxx --disable-static
        # GMP's config template is config.in - not config.h.in, and not
        # config.hin either - so the standard guard has to name it.
        touch aclocal.m4 configure config.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
        make -j1 install-html
    ]]
})
