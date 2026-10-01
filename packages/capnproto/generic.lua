require("capnproto@source")
require("zlib")
require("openssl")

return recipe({
    build = [[
        cp -r $NESTDIR/source/capnproto/* .
        # Cap'n Proto 1.5.0 ships a generated configure (configure.ac is
        # present too, but the release tarball already has it) and its config
        # template is the ordinary config.h.in - AC_CONFIG_HEADERS([config.h])
        # at configure.ac:7, and config.h.in is in the tree.
        #
        # --without-fibers is the load-bearing switch. configure.ac:253-289
        # probes for makecontext/getcontext/swapcontext to decide on fibers,
        # which drive libkj-async's stackful coroutines. Bionic has a
        # <ucontext.h> but declares none of those three functions at ANY API
        # level: compiling a getcontext/makecontext call against
        # aarch64-linux-android21/24/35-clang fails with "call to undeclared
        # library function 'getcontext'" on all three. Left to itself
        # configure would fall through to -lucontext, not find it, and only
        # warn ("won't build with fibers") - which happens to work, but it is
        # a silent capability difference and it would try libucontext, which
        # is not in this prefix. Saying --without-fibers makes the result the
        # same on every system and never probes for a library we do not have.
        # It also keeps the artifact identical everywhere: configure.ac:290-294
        # then sets -DKJ_USE_FIBERS=0 rather than defining KJ_USE_FIBERS.
        #
        # --with-zlib and --with-openssl pin the two optional libraries that
        # DO exist in this prefix. Left at the default "check",
        # configure.ac:196-234 does AC_CHECK_LIB/AC_CHECK_HEADER for them and
        # silently downgrades to "won't build libkj-gzip/libkj-tls" if a probe
        # comes back empty, so the same tree would produce different libraries
        # on different systems depending on probe luck. Passing them makes
        # libkj-gzip and libkj-tls unconditional.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --without-fibers --with-zlib --with-openssl
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Deliberately NOT `make all` and NOT `make install`. Both pull in
        # BUILT_SOURCES (Makefile.am:496), which is $(test_capnpc_outputs),
        # and those come from test_capnpc_middleman, whose rule runs the
        # freshly built TARGET capnp binary:
        #   ./capnp$(EXEEXT) compile ... -o./capnpc-c++$(EXEEXT):src
        # (Makefile.am:487-490). That is a target binary executed on the build
        # machine, which this repo never does, and on a cross build it could
        # not run at all without an emulator. `install` depends on
        # BUILT_SOURCES directly (Makefile.in:3914) and install-am on all-am
        # (Makefile.in:3921), so the plain targets are unusable here.
        #
        # The narrow targets below reach exactly what a consumer needs, and
        # their only prerequisites are the libraries and headers themselves
        # (Makefile.in:1662 install-libLTLIBRARIES: $(lib_LTLIBRARIES)), so
        # none of them can reach BUILT_SOURCES. The libraries themselves need
        # no code generation: every file in capnpc_outputs (Makefile.am:102)
        # - including the compiler's own lexer.capnp.c++ and
        # grammar.capnp.c++ - ships pre-generated in the tarball.
        #
        # bin_PROGRAMS (capnp, capnpc-capnp, capnpc-c++, Makefile.am:416) are
        # left out: they are target binaries nothing in this prefix runs.
        # Generate code with a host capnp instead.
        make -j1 install-libLTLIBRARIES
        make -j1 install-pkgconfigDATA
        make -j1 install-includecapnpHEADERS
        # The .capnp schema files themselves are dist_includecapnp_DATA /
        # dist_includecapnpcompat_DATA, so their install targets carry the
        # "dist_" prefix (Makefile.in:3385,3406); there is no plain
        # install-includedirDATA.
        make -j1 install-dist_includecapnpDATA
        make -j1 install-dist_includecapnpcompatDATA
        make -j1 install-includecapnpcompatHEADERS
        make -j1 install-includekjHEADERS
        make -j1 install-includekjcompatHEADERS
        make -j1 install-includekjparseHEADERS
        make -j1 install-includekjstdHEADERS
    ]]
})