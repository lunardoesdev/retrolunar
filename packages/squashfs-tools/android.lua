-- Bionic has no libpthread at any API level: the NDK 28.2 sysroot ships no
-- libpthread.a under aarch64-linux-android, its lib32, x86_64-linux-android or
-- its lib32, and "aarch64-linux-androidNN-clang -lpthread" fails at the link
-- with "ld.lld: error: unable to find library -lpthread" at API 21 and API 35
-- alike. squashfs-tools' Makefile:271 hardcodes `LIBS = -lpthread -lm` with a
-- plain `=`, and Makefile:483 and :566 put $(LIBS) verbatim on both link
-- lines, so both binaries fail to link on every Android target.
--
require("squashfs-tools@source")

-- Only Android needs this file: glibc and mingw-w64 both have a real
-- libpthread, so the generic recipe is already correct there. Everything
-- else in this file is generic.lua's build with the LIBS line restated;
-- those comments carry the full rationale for LZO_SUPPORT,
-- USE_PREBUILT_MANPAGES and INSTALL_PREFIX.
return recipe({
    build = [[
        cp -r $NESTDIR/source/squashfs-tools/* .
        cd squashfs-tools
        # LIBS is restated here, minus -lpthread. A command-line variable
        # overrides the Makefile's own `LIBS = -lpthread -lm` (Makefile:271),
        # so nothing upstream is edited; the list below is exactly what
        # Makefile:271 + the four selected compressors add -lm (:271), -lz
        # (:276), -llz4 (:300), -llzma (:317), -lzstd (:329) - with the
        # pthread entry dropped. LZO_SUPPORT=0 keeps -llzo2 (:288) out, as in
        # the generic recipe.
        # -pthread is deliberately NOT added: the thread code in thread.c and
        # nprocessors_compat.c calls pthread_create/pthread_join, which live
        # in Bionic's libc, so no link flag is needed at all once -lpthread is
        # gone. The system's LDFLAGS already carry -lm.
        # USE_PREBUILT_MANPAGES=y for the reason given in generic.lua: the
        # alternative renders the manuals by RUNNING the freshly built tools.
        make -j1 LZO_SUPPORT=0 USE_PREBUILT_MANPAGES=y INSTALL_PREFIX="$OUT" \
            LIBS="-lm -lz -llz4 -llzma -lzstd"
        make -j1 LZO_SUPPORT=0 USE_PREBUILT_MANPAGES=y INSTALL_PREFIX="$OUT" \
            LIBS="-lm -lz -llz4 -llzma -lzstd" install
    ]]
})
