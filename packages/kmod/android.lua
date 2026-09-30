-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe.
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
        # The NDK sysroot ships no zlib.pc and no libzstd.pc, so meson's
        # pkg-config lookup cannot resolve either; -Dzlib=disabled keeps meson
        # from erroring on a dependency it cannot find. This is a sysroot fact,
        # not a kmod fact, which is why it is here and not in generic.lua.
        # liblzma.pc is in the prefix, so the xz backend is still enabled.
        meson setup build $MESON_FLAGS \
            -Dbashcompletiondir= \
            -Dfishcompletiondir= \
            -Dmanpages=false \
            -Dzlib=disabled \
            -Dxz=enabled \
            -Dzstd=disabled
        meson compile -C build --jobs 1
        # No DESTDIR: meson's --prefix is already $OUT (it comes from
        # $MESON_FLAGS), so DESTDIR would concatenate the two and the
        # install would land in $OUT$OUT.
        meson install -C build
    ]]
})
