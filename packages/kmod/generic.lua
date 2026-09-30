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
        # The xz backend is enabled because the prefix ships liblzma.pc; zstd
        # is off for the same reason liblzma is preferred, so the backend set
        # does not vary with whatever the host happens to have installed.
        # kmod's zlib backend is an Android question and lives in
        # android.lua, not here.
        meson setup build $MESON_FLAGS \
            -Dbashcompletiondir= \
            -Dfishcompletiondir= \
            -Dmanpages=false \
            -Dxz=enabled \
            -Dzstd=disabled
        meson compile -C build --jobs 1
        # No DESTDIR: meson's --prefix is already $OUT (it comes from
        # $MESON_FLAGS), so DESTDIR would concatenate the two and the
        # install would land in $OUT$OUT.
        meson install -C build
    ]]
})
