require("openblas@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openblas/* .
        # OpenBLAS has no configure and no build-system option that covers the
        # cross case that matters here. Makefile.system:320 shells out to
        # Makefile.prebuild at parse time, and Makefile.prebuild:86-100 runs
        # c_check, f_check, getarch and getarch_2nd and reads their stdout
        # back into Makefile.conf/config.h. Those are host programs and they
        # have to run, so the build cannot be left to autodetect.
        #
        # Two knobs follow from that, and only two.
        #
        # HOSTCC is the BUILD machine's compiler, not the target's. It
        # defaults to $(CC) (Makefile.system:103), which on a cross build is
        # the cross compiler, so getarch would be built as a target binary and
        # Makefile.prebuild:99 would try to execute it here. Upstream's own
        # Android instructions pass HOSTCC explicitly for exactly this reason
        # (docs/install.md:637).
        #
        # TARGET is OpenBLAS's supported-microprocessor name, not a triplet,
        # and it is what makes getarch answer for the target rather than for
        # the build CPU (Makefile.system:102-106 adds -DFORCE_$(TARGET)
        # -DUSER_TARGET). Without it an x86_64 build machine reports x86_64
        # and the build compiles x86_64 hand-written assembly with the target
        # compiler; Makefile:194-195 turns that into an explicit "Detecting
        # CPU failed. Please set TARGET explicitly".
        #
        # Only a cross build needs TARGET. On clang-native, build == host, so
        # getarch measures the machine it is really going to run on and
        # forcing a TARGET there would just bake this build machine's CPU
        # floor into the library. TARGET is also not the same as TARGET=,
        # which Makefile.system:100 would still read as defined.
        if [ "$HOST_TRIPLET" = "$BUILD_TRIPLET" ]; then
          OB_TARGET_ARGS=
        else
          case "$HOST_ARCH" in
            aarch64|armv7a) OB_TARGET_ARGS="TARGET=ARMV8" ;;
            x86_64)          OB_TARGET_ARGS="TARGET=HASWELL" ;;
            i686)            OB_TARGET_ARGS="TARGET=ATOM" ;;
            *) echo "openblas: no OpenBLAS TARGET for HOST_ARCH=$HOST_ARCH" >&2; exit 1 ;;
          esac
        fi
        # NOFORTRAN=1: no system in this prefix exports a Fortran compiler and
        # there is none on this build host either. f_check.pl:54 already
        # reaches the same answer on its own when it finds no Fortran, so this
        # states the result instead of depending on the probe; what is built
        # is BLAS plus the f2c-converted LAPACK, both C.
        # NO_SHARED=1: a static libopenblas.a, like the rest of this prefix.
        #
        # The same variables must be given to the install line: Makefile:132
        # says so, because install re-runs Makefile.install against the same
        # configuration.
        make -j1 HOSTCC=cc $OB_TARGET_ARGS NOFORTRAN=1 NO_SHARED=1 \
             CC="$CC" AR="$AR" RANLIB="$RANLIB" PREFIX=$OUT
        make -j1 HOSTCC=cc $OB_TARGET_ARGS NOFORTRAN=1 NO_SHARED=1 \
             CC="$CC" AR="$AR" RANLIB="$RANLIB" PREFIX=$OUT install
    ]]
})