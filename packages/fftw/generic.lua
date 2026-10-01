require("fftw@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/fftw/* .
        # Static libfftw3.a, the fftw3.h family, fftw3.pc and the FFTW3 cmake
        # package config.
        #
        # No --enable-<isa> flag is passed, which is the whole point: in
        # fftw 3.3.11 every SIMD family defaults OFF at configure time
        # (configure.ac:119 --enable-sse2, :138 --enable-avx2, :192
        # --enable-neon, all "have_*=$enableval, have_*=no"), so this is a
        # plain scalar build and nothing about the build depends on which CPU
        # the build machine happens to be. Configure runs no timing probe and
        # executes no target binary; the per-CPU choice it does make is
        # compile-time and it is ours to make. Add --enable-neon here for an
        # aarch64 SIMD build.
        #
        # --disable-fortran: the Fortran-callable wrappers default ON
        # (configure.ac:679) and need a Fortran compiler, which no system in
        # this prefix has. The C API is what consumers use.
        #
        # --disable-doc: doc/Makefile.am:3 builds info_TEXINFOS through
        # makeinfo, and Texinfo is not buildable here.
        #
        # No PIC flag is passed. libtool's --enable-pic/--with-pic is not
        # fftw's to consult: the word "pic" appears once in configure.ac, at
        # line 333, and it is the MPICC assignment, and PIC never reaches
        # config.h.in at all. Every system in this tree already sets
        # $CFLAGS="-O2 -fPIC", so the archive is position-independent without
        # a flag here.
        #
        # Threads are left off: they default off, and turning them on would
        # run the ACX_PTHREAD probe, which wants a separate -lpthread that no
        # Android sysroot has to offer.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --disable-fortran --disable-doc
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})