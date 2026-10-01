require("freetype")
require("expat")
-- gperf is a HOST program: fontconfig's meson.build:461-493 runs `gperf -L
-- ANSI-C` at configure time and meson.build:475 compiles its output to pick
-- the len type. The fallback at meson.build:485 is `find_program('gperf')`
-- with no required:false, so a missing gperf is a hard configure error, not a
-- degraded build. @native because the cross compilers cannot run it.
require("gperf@native")
-- Same reasoning for python3: meson.build:103 does
-- import('python').find_installation() unconditionally, and
-- meson.build:517-532 runs src/makealias.py to generate fcalias.h and
-- fcftalias.h. @native, so it is the host interpreter and never the target's.
require("python@native")
require("fontconfig@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/fontconfig/* .
        # Static libfontconfig.a, the fontconfig/ headers and fontconfig.pc.
        # Static-only: meson builds shared by default and a target prefix has
        # no loader path for a versioned object. No DESTDIR - $MESON_FLAGS
        # already carries --prefix=$OUT and DESTDIR would make $OUT$OUT.
        #
        # xml-backend=expat pins the XML parser to the expat in this prefix.
        # Left on auto it is still correct (meson.build:76-87 finds expat via
        # pkg-config), but auto has a hard failure downstream: if nothing is
        # found, meson.build:88-91 requires libxml-2.0, which is not here and
        # must not be silently picked up from a host pkg-config path.
        #
        # nls=disabled: the only consumer is gettext, and meson.build:608
        # would otherwise run xgettext and build po/. The bundled
        # subprojects/libintl is a stub that finds nothing (its meson.build:5
        # only looks under /usr/local), so leaving nls on auto buys nothing.
        #
        # tools=disabled: fc-cache, fc-list, fc-query and the rest are target
        # programs this prefix does not ship, and meson.build:587-598 builds
        # ten of them.
        #
        # cache-build=disabled: meson.build (fc-cache/meson.build:12) otherwise
        # registers an install script that RUNS the freshly built fc-cache.
        # It is skipped on a cross build, but clang-native is not a cross
        # build, so the flag is what keeps that from happening on native.
        #
        # tests and tests-external-fonts: the suite is a host program set, and
        # tests-external-fonts defaults to ENABLED, which runs
        # build-aux/fetch-testfonts.py and downloads fonts over the network
        # (test/meson.build:1-14) - forbidden at build time.
        #
        # doc=disabled: the API reference needs xmlto.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static \
            -Dxml-backend=expat -Dnls=disabled -Dtools=disabled \
            -Dcache-build=disabled -Dtests=disabled -Dtests-external-fonts=disabled \
            -Ddoc=disabled
        ninja -C build --parallel 1
        ninja -C build install
    ]]
})