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
        # Deliberately NOT `make all` and NOT `make install`. The reason is
        # that both of their rules RUN the freshly built target capnp binary.
        # BUILT_SOURCES (Makefile.am:496) is $(test_capnpc_outputs), which is
        # produced by test_capnpc_middleman, and that rule executes the target
        # program just linked:
        #   ./capnp$(EXEEXT) compile --src-prefix=$(srcdir)/src \
        #       -o./capnpc-c++$(EXEEXT):src ...
        # (Makefile.am:487-490). Executing a target binary is something this
        # repo never does, and on a cross build the binary could not run at all
        # without an emulator. BUILT_SOURCES is a prerequisite of `all`
        # (Makefile.in:1531), `install` (:3914), `install-exec` (:3916),
        # `check` (:3902) and `distdir` (:3726), so those five targets are all
        # unusable here.
        #
        # The two targets below are the parts of the install that do NOT go
        # through BUILT_SOURCES. install-libLTLIBRARIES is named on its own
        # because it sits in install-exec-am (Makefile.in:4160) next to
        # install-binPROGRAMS, and its only prerequisite is
        # $(lib_LTLIBRARIES) (Makefile.in:1662). install-data is one target
        # that covers the entire header/.pc/CMake half:
        #   install-data: install-data-am            (Makefile.in:3918)
        #   install-data-am: install-cmakeconfigDATA install-dist_includecapnpDATA
        #     install-dist_includecapnpcompatDATA install-includecapnpHEADERS
        #     install-includecapnpcompatHEADERS install-includekjHEADERS
        #     install-includekjcompatHEADERS install-includekjparseHEADERS
        #     install-includekjstdHEADERS install-pkgconfigDATA  (Makefile.in:4149-4154)
        # install-data pulls in install-cmakeconfigDATA, which is how
        # lib/cmake/CapnProto/CapnProtoConfig.cmake lands in $OUT so a
        # consumer's find_package(CapnProto) works.
        #
        # Note what is NOT the reason: capnpc_outputs (Makefile.am:102) is a
        # bare variable that is never a target and never a prerequisite - the
        # .capnp.c++/.capnp.h files are ordinary in-tree sources compiled
        # directly (e.g. c++.capnp.c++ is in libcapnp_la_SOURCES), and they
        # ship that way in the tarball. That is why no library target has to
        # generate anything, and it is why the targets above are safe; but the
        # thing that makes `all` unusable is the RUN in the middleman rule.
        #
        # bin_PROGRAMS (capnp, capnpc-capnp, capnpc-c++, Makefile.am:416) are
        # omitted BY CHOICE, not because the build system forced it: they
        # compile and link fine on a cross build - nothing runs them - and only
        # install-binPROGRAMS is left out here. The cost is real and worth
        # stating: without bin/capnp nothing in this prefix can generate code
        # against these headers, so this is a library-only package, and
        # libcapnpc.a (which IS installed) is the plugin half of a toolchain
        # whose driver half is absent. Consumers generate code with a host
        # capnp.
        make -j1 install-libLTLIBRARIES
        make -j1 install-data
    ]]
})