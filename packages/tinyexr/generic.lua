require("tinyexr@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tinyexr/* .
        # Static library. TINYEXR_BUILD_SAMPLE is the sample viewer
        # (test_tinyexr.cc), a host program. TINYEXR_USE_MINIZ stays ON --
        # upstream's default -- which keeps tinyexr self-contained, at the
        # cost of shipping miniz alongside it (see the copy list below).
        cmake -S . -B build $CMAKE_FLAGS -DTINYEXR_BUILD_SAMPLE=OFF -DTINYEXR_USE_MINIZ=ON
        cmake --build build --parallel 1
        # tinyexr's CMakeLists.txt has NO install() rules at all (verified:
        # grep for "install" returns nothing, and `cmake --install` exits 0
        # without even creating the prefix), so the install is done here with
        # mkdir/cp, which AGENTS.md permits.
        #
        # The copy list is self-consistent by construction, and that is the
        # whole point. tinyexr.h is NOT self-contained and the archive is
        # NOT self-contained:
        #   tinyexr.h:749        #include "exr_reader.hh"
        #   exr_reader.hh:12     #include "streamreader.hh"
        #   tinyexr.h:770        #include <miniz.h>, because
        #                        TINYEXR_USE_MINIZ defaults to 1
        #   libtinyexr.a         carries undefined mz_compress,
        #                        mz_compressBound and mz_uncompress, which
        #                        the separately built libminiz.a supplies
        # Installing only libtinyexr.a and tinyexr.h gives a green build and
        # a prefix nothing can compile against, which is why all three extra
        # files are copied here rather than left to a future reader.
        mkdir -p $OUT/lib $OUT/include
        cp build/lib/libtinyexr.a $OUT/lib/
        cp tinyexr.h exr_reader.hh streamreader.hh $OUT/include/
        cp deps/miniz/miniz.h $OUT/include/
        cp build/libminiz.a $OUT/lib/
    ]]
})
