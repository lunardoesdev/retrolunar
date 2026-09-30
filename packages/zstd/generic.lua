require("zstd@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zstd/* .
        # zstd's lib Makefile derives every object from source with a %.c -> %.o
        # pattern rule (lib/Makefile:52-53, :221), so the 1.5.7 release tree
        # builds from source: it ships no prebuilt .o files (verified - find
        # over the unpacked tree returns zero). That matters on a cross build,
        # because a stale host object would be archived into libzstd.a with no
        # architecture check anywhere. If a future release ever does ship .o
        # files, delete them before building rather than relying on a flag -
        # this Makefile has no switch for it.
        # HAVE_LZMA/HAVE_ZLIB are 0 because neither lzma nor zlib is a
        # dependency of anything in this prefix yet; PREFIX and LIBDIR are
        # what its install rules expect. The same two variables are passed
        # again for `programs`, where they decide whether zstd and zstdcat
        # link the optional compressors; that is deliberate, so the two
        # directories stay consistent, and enabling compression later is a
        # two-line change (packages/xz already exists to supply liblzma).
        make -C lib PREFIX="$OUT" LIBDIR="$OUT/lib" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX"
        make -C lib PREFIX="$OUT" LIBDIR="$OUT/lib" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX" install
        make -C programs PREFIX="$OUT" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX"
        make -C programs PREFIX="$OUT" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX" install
    ]]
})
