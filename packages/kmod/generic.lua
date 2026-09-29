require("kmod@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/kmod/. .
        # Completion directories are disabled because the shell completions are
        # installed to absolute paths that $OUT does not own.
        #
        # Man pages are turned off because man/meson.build:1 does an
        # unconditional find_program('scdoc'), which is not in this prefix.
        #
        # Only the xz backend is enabled: the prefix ships liblzma.pc but has
        # no zlib.pc and no libzstd.pc, so meson's pkg-config lookup cannot
        # resolve the other two.
        meson setup build $MESON_FLAGS \
            -Dbashcompletiondir= \
            -Dfishcompletiondir= \
            -Dmanpages=false \
            -Dzlib=disabled \
            -Dxz=enabled \
            -Dzstd=disabled
        meson compile -C build
        DESTDIR="$OUT" meson install -C build
    ]]
})
