require("libogg")
require("opus")
require("opusfile@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/opusfile/* .
        # Static libopusfile against the libogg and libopus in this prefix.
        # configure.ac:125 makes this an unconditional
        # PKG_CHECK_MODULES([DEPS], [ogg >= 1.3 opus >= 1.0.1]) with no default,
        # so both are hard requirements, not probes.
        # --without-libcurl is deliberately NOT passed; the switch that exists
        # is --disable-http (configure.ac:71). HTTP support pulls
        # PKG_CHECK_MODULES([URL_DEPS], [openssl]) at configure.ac:120 and adds
        # src/http.c, which is a network client a target prefix has no use for.
        # --disable-examples turns off opus_example and opus_decode_example,
        # host programs (configure.ac:153, default ON).
        # --disable-doc drops the doxygen and dot requirements (configure.ac:170).
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic \
            --disable-http --disable-examples --disable-doc
        # opusfile's config template is a top-level config.h.in, named by
        # AC_CONFIG_HEADERS([config.h]) at configure.ac:192.
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})