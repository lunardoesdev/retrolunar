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
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-static \
            --docdir=$OUT/share/doc/gettext-0.26
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
        # preloadable_libintl.so is meant to be LD_PRELOADed; the
        # installed mode 0644 would be useless.
        chmod 0755 $OUT/lib/preloadable_libintl.so
    ]]
})
