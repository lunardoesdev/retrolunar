require("zstd@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/zstd/* .
        # The release tarball ships prebuilt object files for common targets,
        # so the lib Makefile is told to compile from source rather than pick
        # one up. PREFIX and LIBDIR are what its install rules expect.
        make -C lib PREFIX="$OUT" LIBDIR="$OUT/lib" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX"
        make -C lib PREFIX="$OUT" LIBDIR="$OUT/lib" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX" install
        make -C programs PREFIX="$OUT" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX"
        make -C programs PREFIX="$OUT" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX" install
    ]]
})
