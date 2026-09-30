require("fribidi@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/fribidi/* .
        # Static library, header and pkg-config file. fribidi 1.0.16's meson
        # build has only three options - tests, docs and the command line
        # tools - and all three are host-side, so they go off.
        # default_library=static because meson builds shared by default and a
        # target prefix has no loader path for a versioned object. No DESTDIR:
        # meson's --prefix is already $OUT, and DESTDIR would concatenate the
        # two into $OUT$OUT.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static -Dtests=false -Ddocs=false -Dbin=false
        ninja -C build
        ninja -C build install
    ]]
})
