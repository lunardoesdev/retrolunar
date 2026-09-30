require("gettext@source")

-- LFS flags: shared libraries only, docs under the prefix.
return recipe({
    build = [[
        cp -r $NESTDIR/source/gettext/* .
        # The NDK hides iconv.h's declarations until API 28, so Gettext's
        # "checking for iconv" probe fails and libtextstyle is built with
        # HAVE_ICONV=0. That selects the abort() stub at
        # libtextstyle/lib/iconv-ostream.c:247, whose one-argument
        # flush is stored in a two-argument function-pointer slot at
        # line 297 -- a warning in C89/C99 mode, a hard error under
        # clang 16+. Downgrading that one diagnostic gets the tree past
        # compilation; the link still fails afterwards because the
        # HAVE_ICONV=0 build omits iconv_ostream_create, which
        # libtextstyle/lib/libtextstyle.sym.in:41 exports.
        CFLAGS="$CFLAGS -Wno-error=incompatible-function-pointer-types"
        export CFLAGS
        # No --docdir: upstream's default already lands under $OUT, and
        # pinning a version here would go stale on a bump.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-static
        # Gettext has no top-level config header by design: configure.ac has
        # no AC_CONFIG_HEADERS at all, and the five real templates live in
        # the sub-configures (gettext-runtime, gettext-runtime/intl,
        # gettext-runtime/libasprintf, gettext-tools, libtextstyle). So
        # sweep for them rather than naming a path that does not exist.
        #
        # The find sweeps below are deliberate, not untidy. Enumerating the
        # five template paths by hand would cover exactly this release and
        # would need editing on every version that adds or drops a
        # sub-configure; a name sweep covers all five and any future one with
        # no change. Prefer find over enumeration here -- do not "tidy" it
        # back into a list of paths.
        touch aclocal.m4 configure
        find . -name 'config.h.in' | xargs touch
        # The sub-configures have their own maintainer rules over configure
        # and aclocal.m4; sweep those too so autoheader/autoconf cannot
        # re-run from a tarball mtime.
        find . -name 'configure' | xargs touch
        find . -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
        # preloadable_libintl.so is meant to be LD_PRELOADed; the
        # installed mode 0644 would be useless.
        chmod 0755 $OUT/lib/preloadable_libintl.so
    ]]
})
