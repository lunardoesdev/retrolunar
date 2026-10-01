-- Every AC_CHECK_LIB below is a hard error, not a warning:
-- configure.ac:115-124 AC_CHECK_LIB(m|sqrt), (z|compress2), (bz2|BZ2_bzBuffToBuffCompress),
-- (lzo2|lzo1x_1_compress), (lz4|LZ4_compress_default) each pass AC_MSG_ERROR as the
-- failure action, and configure.ac:113 does the same for (pthread|pthread_create).
-- All five are link probes, so the libraries must really be in $PREFIX.
require("zlib")
require("bzip2")
require("lz4")
-- lzo2: configure.ac:121-122 AC_CHECK_LIB(lzo2, lzo1x_1_compress, , AC_MSG_ERROR).
-- The name upstream ships is "lzo" (liblzo2 installs as lib/lzo2.a + lzo/lzo1x.h),
-- the same package lzop needs, so both recipes require the same package.
require("lzo")
-- man/Makefile.am:6 BUILT_SOURCES builds five .1 pages from .pod with pod2man, and
-- pod2man is a host perl script: it must be a native build tool, not a target one.
require("perl@native")
require("lrzip@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lrzip/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # configure.ac:21 is AC_CONFIG_HEADERS([config.h]), so the template is the
        # automake default name config.h.in - present in the 126-entry tarball
        # index and 8696 bytes on disk.
        touch aclocal.m4 configure config.h.in
        # Four sub-Makefiles are configured from one configure: configure.ac:134-140
        # AC_CONFIG_FILES covers Makefile, lzma/Makefile, lzma/C/Makefile,
        # doc/Makefile and man/Makefile, and the tree carries a Makefile.in in
        # each of those five places. The sweep covers all of them.
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
