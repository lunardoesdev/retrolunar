require("cairo")
require("harfbuzz")
require("fribidi")
require("fontconfig")
require("freetype")
-- GLib is a hard dependency, not an optional one: pango meson.build:233-235
-- looks up glib-2.0, gobject-2.0 and gio-2.0 with no required:false, and
-- meson.build:211-214 pins the floor at GLib 2.88. There is no
-- packages/glib in this prefix today, so this recipe will not configure until
-- one is added. See stage1.md.
require("glib")
require("pango@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/pango/* .
        # Static libpango*.a, the pango/ headers and pango*.pc.
        # Static-only: meson builds shared by default and a target prefix has
        # no loader path for a versioned object. No DESTDIR - $MESON_FLAGS
        # already carries --prefix=$OUT, so DESTDIR would make $OUT$OUT.
        #
        # The three dependencies meson.build:233-238 requires outright are
        # glib-2.0, gobject-2.0, gio-2.0 and fribidi; harfbuzz follows at
        # meson.build:281 and cairo at meson.build:380 (default 'enabled').
        #
        # xft=disabled: an X11 client library. There is no X server on any
        # target here, and meson.build:337 would resolve it through a host
        # pkg-config path if left on auto.
        # libthai=disabled: optional (meson.build:240), not in this prefix.
        # sysprof=disabled: already the default (meson.options:38-41), named
        # so the intent is recorded.
        # introspection=disabled: needs g-ir-scanner (meson.build:533), a host
        # gobject-introspection tool.
        # documentation=false and man-pages=false: need gi-docgen, rst2man and
        # rst2html5 (docs/meson.build:1,221-222); already false upstream.
        # build-testsuite=false and build-examples=false: example and test
        # program sets (meson.options:23-31), both defaulting to true.
        #
        # fontconfig stays on 'auto' and resolves to enabled on every non-Windows
        # target: meson.build:259-261,288-296 make fontconfig REQUIRED where
        # host_system is not windows/darwin, and meson.build:288 errors out
        # explicitly if it is disabled there. Same for freetype, which follows
        # fontconfig at meson.build:305-309.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static \
            -Dxft=disabled -Dlibthai=disabled -Dsysprof=disabled \
            -Dintrospection=disabled -Ddocumentation=false -Dman-pages=false \
            -Dbuild-testsuite=false -Dbuild-examples=false
        ninja -C build --parallel 1
        ninja -C build install
    ]]
})