require("pixman")
require("freetype")
require("fontconfig")
require("libpng")
require("zlib")
-- python3 is a HOST tool here, in two separate places. meson.build:3 runs
-- version.py to compute the project version, and boilerplate/meson.build:26
-- runs make-cairo-boilerplate-constructors.py to generate a C file.
require("python@native")
require("cairo@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cairo/* .
        # Static libcairo.a, the cairo/ headers, cairo.pc and one .pc per
        # built backend. Static-only: meson builds shared by default and a
        # target prefix has no loader path for a versioned object. No DESTDIR:
        # $MESON_FLAGS already carries --prefix=$OUT, so DESTDIR would
        # concatenate the two into $OUT$OUT.
        #
        # Backends explicitly DISABLED, each for a named reason:
        #   xlib, xcb, xlib-xcb - X11. There is no X server on any target
        #     here, and these default to 'auto', which would let a host
        #     pkg-config path supply them. xlib also drags in a run check:
        #     meson.build:393-401 runs a compiled test program for
        #     IPC_RMID_DEFERRED_RELEASE, which a cross target binary cannot do.
        #   quartz - macOS only (meson.build:470 gates on
        #     host_machine.system() == 'darwin'); off so the option is
        #     explicit rather than inert.
        #   dwrite - Windows-only (meson.build:504). This prefix builds
        #     mingw without DirectWrite, and pango's Windows backend is not a
        #     target here.
        #   glib - the gobject/gobject-function backend (meson.build:587-595).
        #     glib is NOT in this prefix.
        #   lzo - meson.build:220. Optional; not in this prefix.
        #   spectre - meson.build:647. Only feeds PS-surface tests.
        #   symbol-lookup - meson.build:631. Needs binutils/bfd, a HOST
        #     facility that must not end up in a target library.
        #   gtk2-utils - already 'disabled' upstream (meson.options:20); named
        #     so the intent is recorded.
        #   tests - host test, perf and boilerplate program sets
        #     (meson.build:843-846).
        #
        # Backends explicitly ENABLED, each named so the reason is on record:
        #   png=enabled gives cairo-png and cairo-svg (meson.build:260-274),
        #     libpng is in this prefix.
        #   zlib=enabled gives cairo-ps, cairo-pdf and cairo-script
        #     (meson.build:600-629), zlib is in this prefix.
        #   freetype=enabled gives cairo-ft, freetype is in this prefix.
        #   fontconfig=enabled gives cairo-fc, fontconfig is in this prefix.
        #     cairo-ft.h includes fontconfig.h, which is why meson.build:336
        #     attaches fontconfig's compile args to the cairo-ft feature.
        # pixman is enabled by no switch at all: meson.build:677-680 looks it
        # up unconditionally, because the image surface is core cairo.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static \
            -Dpng=enabled -Dzlib=enabled -Dfreetype=enabled -Dfontconfig=enabled \
            -Dxlib=disabled -Dxcb=disabled -Dxlib-xcb=disabled -Dquartz=disabled \
            -Ddwrite=disabled -Dglib=disabled -Dlzo=disabled -Dspectre=disabled \
            -Dsymbol-lookup=disabled -Dgtk2-utils=disabled -Dtests=disabled
        ninja -C build --parallel 1
        ninja -C build install
    ]]
})