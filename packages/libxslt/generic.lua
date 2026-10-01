require("libxml2")
require("libxslt@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libxslt/* .
        # --without-python is not optional here. Unlike libxml2 2.15.4, this
        # libxslt still probes Python whenever the option is merely unset:
        # configure.ac:190 runs PKG_CHECK_MODULES([PYTHON], [python-N])
        # with no action-if-not-found, so a missing python-N.pc is a hard
        # configure error. Every system here points PKG_CONFIG_LIBDIR at
        # $PREFIX only, so no host python-N.pc is ever visible. The bindings
        # are a host-side feature anyway and have no place in a target prefix.
        #
        # --without-debugger is upstream's default already (configure.ac:267
        # tests `!= "yes"`, so an unset option leaves WITH_DEBUGGER=0); it is
        # spelled out because the debugger is a host-side development aid
        # and an upstream default flip must not drag it into a cross build.
        #
        # Everything else stays at its default: zlib/lzma are not offered,
        # --with-crypto is off (configure.ac:205) and --with-plugins is off
        # (configure.ac:449-451). libxml2 is found through pkg-config against
        # $PREFIX (configure.ac:405-413) from the libxml2 recipe above; the
        # xml2-config fallback at configure.ac:420 is not reached because
        # PKG_CHECK_MODULES succeeds first.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --without-python --without-debugger
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})