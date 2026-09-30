require("openssl")
require("libevent@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libevent/* .
        # Static libraries, with the OpenSSL backend from this prefix: the
        # pkg-config search path is the prefix, so configure finds it. The
        # sample programs, the regression suite and the benchmark are host
        # programs and stay off.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --enable-openssl --disable-samples --disable-libevent-regress --disable-benchmark
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
