-- squashfs-tools 4.7.2 is a hand-written Makefile, NOT autotools: there is no
-- configure, no configure.ac and no config template of any name in the tree.
-- Compressor support is a set of Makefile variables, and every one that is on
-- adds a library to LIBS:
--   gzip -> -lz (Makefile:276), lz4 -> -llz4 (:300), xz -> -llzma (:317),
--   zstd -> -lzstd (:329), lzo -> -llzo2 (:288).
-- The compressors that have a package in this prefix are required; the one
-- that does not (lzo) is switched off below rather than dropped silently.
require("zlib")
require("xz")
require("lz4")
require("zstd")
require("squashfs-tools@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/squashfs-tools/* .
        # The Makefile lives in the squashfs-tools/ subdirectory, and its install
        # rule calls "generate-manpages/install-manpages.sh $(shell pwd)/..",
        # which requires that $(pwd)/.. to contain squashfs-tools/generate-manpages.
        # Running from the subdirectory is what makes that path resolve.
        cd squashfs-tools
        # LZO_SUPPORT: Makefile:64 turns LZO on by default and Makefile:288 then
        # adds -llzo2. There is no liblzo2 in this prefix, so it is switched off.
        # A command-line variable overrides the Makefile's own assignment
        # (Makefile:64 `LZO_SUPPORT = 1`) whatever its = or ?= form.
        # COMP_DEFAULT stays gzip (Makefile:88), and gzip is still selected.
        # USE_PREBUILT_MANPAGES=y: Makefile:167 defaults to "n", which makes
        # install-manpages.sh look for help2man and, finding it, RUN the freshly
        # built mksquashfs/unsquashfs to render their own manuals. Running a
        # target binary is exactly what this repo never does. "y" takes the
        # pre-built pages in Documentation/manpages instead.
        # INSTALL_PREFIX: Makefile:174-176 default to /usr/local.
        make -j1 LZO_SUPPORT=0 USE_PREBUILT_MANPAGES=y INSTALL_PREFIX="$OUT"
        make -j1 LZO_SUPPORT=0 USE_PREBUILT_MANPAGES=y INSTALL_PREFIX="$OUT" install
    ]]
})
