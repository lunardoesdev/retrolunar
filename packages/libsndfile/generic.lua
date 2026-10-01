require("libogg")
require("libvorbis")
require("flac")
require("opus")
require("libsndfile@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libsndfile/* .
        # Static libsndfile with the Xiph codecs this prefix already has.
        #
        # libsndfile's external codec support is all or nothing, and the set is
        # exactly flac + ogg + vorbis + vorbisenc + opus: configure.ac:321 sets
        # HAVE_EXTERNAL_XIPH_LIBS only when all five probes succeed, and
        # configure.ac:343 downgrades enable_external_libs to "no" with a
        # warning naming them if any one is missing. Every one of the five is
        # in this prefix, so the probes succeed and the codecs are compiled in
        # with nothing switched off.
        #
        # --disable-mpeg keeps LAME/MPG123 out; neither is in this prefix and
        # MP3 support would otherwise be a silent partial (configure.ac:159).
        # --disable-alsa: ALSA is Linux-only and irrelevant on Android, mingw
        # and a target prefix generally (configure.ac:153).
        #
        # The ten bin_PROGRAMS (sndfile-info, sndfile-play, sndfile-convert and
        # the rest, Makefile.am:489-492) are gated by AM_CONDITIONAL(FULL_SUITE)
        # at configure.ac:167, whose test is "!= xno" — so they are ON by
        # default despite the help text claiming default=no, and plain make both
        # builds and installs them. --disable-full-suite is the real switch and
        # is what drops the ten target executables and the man pages from every
        # system. This is a library package.
        #
        # It does NOT fix the mingw failure recorded in stage1.md: src/file_io.c
        # is unconditionally in the library (Makefile.am:81), so the S_ISSOCK
        # problem at file_io.c:499 happens regardless of this flag. That one is
        # a system-level blocker for the builder to record, not something this
        # recipe can paper over.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared \
            --disable-mpeg --disable-alsa --disable-sqlite --disable-full-suite
        # libsndfile's config template is src/config.h.in, named by
        # AC_CONFIG_HEADERS([src/config.h]) at configure.ac:31. It is not a
        # top-level config.h.in.
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})