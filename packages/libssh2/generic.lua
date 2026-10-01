require("openssl")
require("zlib")
require("libssh2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libssh2/* .
        # Static libssh2 against the OpenSSL in this prefix. --with-crypto is
        # spelled out rather than left on auto: acinclude.m4:856 walks the
        # backend list in order and the first one whose headers and library
        # link wins, so which backend gets chosen would depend on what else is
        # visible in $PREFIX. OpenSSL is the only one of the five this prefix
        # can satisfy (libgcrypt, mbedtls, gnutls and wolfssl aside, openssl
        # is the package present), and naming it is what makes the .pc's
        # Requires.private: libcrypto deterministic.
        # --with-libz: the in-prefix zlib. configure.ac:157 probes it with
        # AC_LIB_HAVE_LINKFLAGS([z]), so leaving it on auto would silently
        # disable compression if the probe failed.
        # --disable-examples-build turns off the sample client/server, which
        # are host programs; configure.ac:289 makes this the default ON.
        # --disable-docker-tests and --disable-sshd-tests keep the test
        # harness from wanting a container or an sshd (configure.ac:274,281).
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic \
            --with-crypto=openssl --with-libz \
            --disable-examples-build --disable-docker-tests --disable-sshd-tests
        # libssh2's config template is src/libssh2_config.h.in, named by
        # AC_CONFIG_HEADERS([src/libssh2_config.h]) at configure.ac:10. It is
        # not a top-level config.h.in.
        touch aclocal.m4 configure src/libssh2_config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})