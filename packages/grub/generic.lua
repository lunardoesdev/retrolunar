require("grub@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/grub/* .
        # GRUB is a bootloader: upstream and LFS both require a clean
        # environment. The optimization and include-path flags the system
        # exports for ordinary targets are dropped here on purpose.
        unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
        # grub's AC_CHECK_TOOL probes for aarch64-linux-android-<tool> and
        # then for a bare <tool>, which on this host resolves to GNU
        # binutils. Those cannot read an aarch64 ELF ("Unable to
        # recognise the architecture of the input file"), and the NDK ships
        # only the llvm- prefixed names, so point grub's tool variables at
        # the ones the system already exports.
        # These must be exported: configure reads them from the
        # environment, and an unexported shell variable never reaches it.
        export TARGET_OBJCOPY="$OBJCOPY"
        export TARGET_NM="$NM"
        export TARGET_STRIP="$STRIP"
        export TARGET_RANLIB="$RANLIB"
        # NDK clang defaults to PIE, but grub-core's kernel image is built
        # with -mcmodel=large, which clang only accepts together with
        # -fno-pic. A bootloader is not position-independent, so building it
        # that way is upstream's expectation, not a shim. This must not go
        # into $CFLAGS at configure time: configure's own flex probe links
        # the generated scanner, and -fno-pic makes that link fail with
        # "improper alignment for relocation R_AARCH64_LDST64_ABS_LO12_NC".
        # It is therefore appended to TARGET_CFLAGS on the make line below.
        # -fno-pie is needed for the same reason on the link side: the NDK
        # driver passes -pie by default, which ld.lld rejects against the
        # -Wl,-r relocatable link grub uses to build its .module files
        # ("-r and -pie may not be used together").
        # The release tarball omits these entries from extra_deps.lst,
        # which grub-core needs to link the bli/gpt modules.
        cat > grub-core/extra_deps.lst <<'EOF'
        depends bli part_gpt
        EOF
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --sysconfdir=/etc \
            --disable-efiemu \
            --disable-werror
        touch aclocal.m4 configure config.h.in
        # gentpl.py regenerates Makefile.util.am from Makefile.util.def, and
        # Makefile.in depends on it, so a freshly regenerated copy would make
        # make re-run automake looking for automake-1.16, which this prefix
        # does not have. Touch it before the Makefile.in sweep below, so
        # Makefile.in ends up the newer of the two and the re-run never
        # triggers.
        touch Makefile.util.am
        find . -name 'Makefile.in' | xargs touch
        make TARGET_CFLAGS+=" -fno-pic" TARGET_LDFLAGS+=" -fno-pie -no-pie"
        make install
    ]]
})
