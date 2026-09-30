require("zlib")
require("curl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/curl/* .
        # TLS is left to the system's default detection here: glibc and
        # mingw-w64 both have a real stderr symbol, so nothing stands in the
        # way of a TLS backend on those systems. The Android family drops it,
        # for a reason that is an Android fact rather than a
        # target-independent one; see android.lua.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --with-zlib="$PREFIX" --without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3 --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-docs
        touch aclocal.m4 configure lib/curl_config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 -C lib
        # Install only the library, the public headers and the .pc. The
        # top-level 'make install' would also install bin/curl, the curl
        # config script and the docs, none of which belong in a target prefix.
        make -C lib install
        make -C include install
        make install-pkgconfigDATA
    ]]
})
