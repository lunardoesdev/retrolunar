require("zlib")
require("curl@source")

-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe.
return recipe({
    build = [[
        cp -r $NESTDIR/source/curl/* .
        # No TLS backend on Android. This is a deliberate capability
        # reduction, not a build workaround: this recipe does not require
        # openssl at all, so the flag here means libcurl speaks plain HTTP
        # and FTP only. It cannot simply be switched on because the prefix's
        # OpenSSL static archives reference stderr, which Bionic provides as
        # a macro below API 23 (a real symbol needs 23+), so a static link
        # fails on the older Android systems. It lives here rather than in
        # generic.lua because that wall is an Android fact, not a
        # target-independent one.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-ssl --with-zlib="$PREFIX" --without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3 --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-docs
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
