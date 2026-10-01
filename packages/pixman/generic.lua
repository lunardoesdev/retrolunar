require("pixman@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/pixman/* .
        # Static library, pixman-1 headers and pixman-1.pc. pixman has no
        # dependencies of its own: meson.build:466-467 probes only libm and
        # threads, both of which the toolchain provides.
        #
        # default_library=static because meson builds shared by default and a
        # target prefix has no loader path for a versioned object. No DESTDIR:
        # $MESON_FLAGS already carries --prefix=$OUT, so DESTDIR would
        # concatenate the two into $OUT$OUT.
        #
        # tests and demos are host program suites (meson.build:602-612 pulls in
        # test/ and demos/, and demos additionally want gtk+-3.0 and glib-2.0
        # per meson.build:443-444). libpng feeds only the test suite
        # (meson.build:447-465), so it goes with them. gtk is the demos'
        # dependency and is disabled for the same reason.
        #
        # openmp defaults to auto and resolves to NDK's libomp on Android,
        # which would set USE_OPENMP (meson.build:431-435); its only consumer
        # is test/ (pixman/test/composite.c:512) and the blue-noise generator,
        # neither of which this build produces.
        #
        # buildtype: pixman's own default_options pins debugoptimized
        # (meson.build:27), and this prefix ships optimised static archives.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static \
            -Dtests=disabled -Ddemos=disabled -Dlibpng=disabled -Dgtk=disabled \
            -Dopenmp=disabled
        ninja -C build --parallel 1
        ninja -C build install
    ]]
})