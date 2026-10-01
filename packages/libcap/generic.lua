require("libcap@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libcap/* .
        # libcap has no configure at all and no autotools: it is a hand-written
        # make build driven by Make.Rules, and there is no config.h.in,
        # config.hin, configh.in or any other template to guard, because
        # nothing is autoheader-generated. Only the library+tools subdirectory
        # is wanted; the top-level Makefile also recurses into pam_cap, go,
        # tests, progs and doc.
        #
        # The toolchain must go ON THE MAKE LINE, not in the environment.
        # Make.Rules:68 is a hard assignment,
        #     CC := $(CROSS_COMPILE)gcc
        # and `:=` inside the makefile beats an exported environment variable,
        # so an exported CC would be silently ignored and every object would be
        # built with a bare host `gcc`. Variables named on the make command
        # line override makefile assignments of any kind, so CC/AR/RANLIB
        # passed this way are the ones that win.
        #
        # BUILD_CC is the exception that must NOT be the target compiler.
        # libcap/Makefile:82-86 builds _makenames with BUILD_CC and then RUNS it
        # (./_makenames > cap_names.h) to generate the capability-name table
        # that libcap.h:29 includes. Make.Rules:88 defaults BUILD_CC to $(CC),
        # so on a cross build the generated table would be produced by running
        # a target binary - impossible without an emulator. BUILD_CC is
        # therefore the host compiler, following the same convention
        # packages/texinfo/generic.lua:7 already uses.
        #
        # lib=lib: Make.Rules:20-22 otherwise derives the libdir by running
        # `ldd /usr/bin/ld` on the BUILD MACHINE and cutting the result, which
        # answers "lib64" on this host and would install to $OUT/lib64. Every
        # other package here installs to lib, and $PREFIX/lib is what the
        # systems' PKG_CONFIG_LIBDIR and LDFLAGS search. Spelling it out is
        # what keeps the .pc findable.
        #
        # prefix=$OUT: Make.Rules:32-43 switches the install layout to
        # autoconf-style prefixes, so LIBDIR/INCDIR/PKGCONFIGDIR all derive
        # from it and the install lands straight in $OUT.
        #
        # SHARED=no: this prefix is static-only, and it also avoids the
        # loader.txt step (libcap/Makefile:118-122), which builds an
        # executable and runs OBJCOPY --dump-section over it.
        # PTHREADS=yes builds libpsx, whose sources compile on every target.
        # USE_GPERF=no: Make.Rules:106 probes `which gperf` on the build
        # machine, so leaving it on would make cap_text.c compile differently
        # depending on whether gperf happens to be installed. No is the
        # portable path (libcap/Makefile:141 falls back cleanly).
        # PAM_CAP=no and GOLANG=no keep the top-level Makefile from recursing
        # into pam_cap and the Go bindings.
        make -j1 -C libcap CC="$CC" AR="$AR" RANLIB="$RANLIB" BUILD_CC="cc" \
          lib=lib prefix="$OUT" SHARED=no PTHREADS=yes USE_GPERF=no \
          PAM_CAP=no GOLANG=no
        make -j1 -C libcap install CC="$CC" AR="$AR" RANLIB="$RANLIB" BUILD_CC="cc" \
          lib=lib prefix="$OUT" SHARED=no PTHREADS=yes USE_GPERF=no \
          PAM_CAP=no GOLANG=no
    ]]
})