require("gumbo@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gumbo/* .
        # Static libgumbo.a, the two public headers and gumbo.pc. Gumbo is a
        # real C99 library (the parser itself, src/parser.c and friends), not
        # a header package.
        #
        # Installed, exactly as upstream lays it out (meson.build):
        #   lib/libgumbo.a                 meson.build:58-64 library()
        #   include/gumbo.h                 meson.build:66 install_headers()
        #   include/tag_enum.h              meson.build:66 install_headers()
        #   lib/pkgconfig/gumbo.pc          meson.build:68-69 pkg.generate()
        # There is no CMake package config; gumbo ships no CMakeLists.txt.
        #
        # default_library=static is required: meson.build:5 sets
        # default_options to default_library=both, and meson builds shared by
        # default anyway. A target prefix has no loader path for
        # libgumbo.so.4.0.0 (the version meson.build:61 pins).
        #
        # tests=false is load-bearing. meson_options.txt defaults tests to
        # TRUE, and meson.build:87-118 then does add_languages('cpp'),
        # dependency('gtest_main') and builds an 11-file C++ test executable,
        # plus a test() that RUNS it. A missing gtest_main is a hard configure
        # error, and running a target binary on a cross build is forbidden.
        #
        # examples / fuzz / python already default false (meson_options.txt)
        # and are passed explicitly so the intent is visible: examples build
        # six host programs, fuzz requires clang and libFuzzer plus
        # -fsanitize flags (meson.build:29-56), and python requires the shared
        # library (meson.build:72-74) which -Ddefault_library=static forbids.
        #
        # No DESTDIR: --prefix=$OUT already comes from $MESON_FLAGS, so
        # DESTDIR would concatenate into $OUT$OUT.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static -Dtests=false -Dexamples=false -Dfuzz=false -Dpython=false
        meson compile -C build --jobs 1
        meson install -C build
    ]]
})
