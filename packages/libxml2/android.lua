require("libxml2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libxml2/* .
        # --without-python / --without-docs: see generic.lua; both are this
        # release's upstream default and both keep a host toolchain out of a
        # cross build.
        #
        # iconv is the one genuinely Android-specific switch, and it turns on
        # an API-level fact rather than a target triple. Bionic keeps iconv()
        # in libc with no separate libiconv, and its iconv.h declares
        # iconv_open() only from API 28
        # ($SYSROOT/usr/include/iconv.h, __BIONIC_AVAILABILITY_GUARD(28)).
        # libxml2 probes for iconv WITHOUT -liconv first
        # (configure.ac:860-864) and only falls back to -liconv
        # (configure.ac:866-872), so at API >= 28 the first probe links
        # against libc and reports "none required" - no -liconv needed, and
        # ICONV_LIBS stays empty. Below 28 the declaration is absent, both
        # probes fail, and configure aborts with "libiconv not found"
        # (configure.ac:878-880) because there is no libiconv to fall back
        # to. Turning iconv off below 28 leaves the built-in ISO-8859-X
        # tables in place (--with-iso8859x, default on, configure.ac:88).
        _iconv_flags=""
        if [ "$ANDROID_API" -lt 28 ]; then
            _iconv_flags="--without-iconv"
        fi
        ./configure $AUTOCONF_CONFIGURE_FLAGS --without-python --without-docs $_iconv_flags
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})