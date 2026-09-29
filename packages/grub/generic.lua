require("grub@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/grub/* .
        # GRUB is a bootloader: upstream and LFS both require a clean
        # environment. The optimization and include-path flags the system
        # exports for ordinary targets are dropped here on purpose.
        unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
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
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
