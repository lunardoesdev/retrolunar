require("protobuf-c@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/protobuf-c/* .
        # libprotobuf-c, protobuf-c/protobuf-c.h, the .proto, and
        # libprotobuf-c.pc. No dependency on Google protobuf: see below.
        #
        # --disable-protoc is the whole point of this recipe, and it is what
        # makes protobuf-c buildable here today despite packages/protobuf/
        # being unbuilt (it has stage1.md and stage2.md but no stage3.md).
        # Every trace of a protobuf dependency lives inside the protoc branch
        # of configure.ac, which that switch skips:
        #   * configure.ac:68 declares it, and :70 puts the whole check
        #     inside `if test "x$enable_protoc" != "xno"`, including the
        #     PKG_CHECK_MODULES([protobuf], [protobuf >= 3.0.0]) at :73 that
        #     topackage.md:168 records as the blocker.
        #   * configure.ac:89 then RUNS the found protoc to get a version
        #     string (PROTOBUF_VERSION="$($PROTOC --version)"), which is a
        #     host program executed during configure.
        #   * Makefile.am:75 opens `if BUILD_COMPILER`, and everything that
        #     needs protoc or protobuf C++ lives inside it: the protoc-gen-c
        #     program and its sources (:76-97), its -lprotoc/$(protobuf_LIBS)
        #     link (:110-112), and the BUILT_SOURCES rule at :114-120 that
        #     invokes @PROTOC@ to generate protobuf-c.pb.cc/.h. The
        #     install-exec-hook that symlinks bin/protoc-c to protoc-gen-c
        #     (:125-127) is in the same block, so nothing dangles.
        # The library itself needs none of it: Makefile.am:50-52 lists
        # libprotobuf-c's sources as protobuf-c/protobuf-c.c and
        # protobuf-c/protobuf-c.h only - no generated files, no C++ - and
        # protobuf-c/libprotobuf-c.pc.in carries no Requires.private. The
        # whole implementation is portable C: protobuf-c.c includes only
        # stdlib.h and string.h (:48-49) and protobuf-c.h only assert.h,
        # limits.h, stddef.h and stdint.h (:200-203), so it is the same on
        # every system and every API level.
        #
        # Dropping protoc-gen-c is the same decision packages/protobuf/
        # generic.lua already records for protoc itself: a code generator is
        # not a runtime library, so a target prefix has no use for the
        # binary, and a target protoc-gen-c could never be run here anyway.
        # Code generation is a host job - use a host protoc with this
        # library's headers.
        #
        # The cmake build in build-cmake/ is deliberately not used. It looks
        # for protobuf unconditionally, before the BUILD_PROTOC option is
        # even declared: build-cmake/CMakeLists.txt:18-26 runs
        # find_package(Protobuf CONFIG) and falls back to
        # find_package(Protobuf REQUIRED), and :28 adds find_package(absl
        # CONFIG) - all before `option ( BUILD_PROTOC "Build protoc-gen-c" ON )`
        # at :48. So -DBUILD_PROTOC=OFF would not remove the dependency
        # there, while --disable-protoc removes it completely here.
        #
        # --enable-static --disable-shared --with-pic is the prefix-wide
        # static convention (libcbor, c-ares, curl, jansson, lame,
        # libarchive and the rest).
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-protoc
        # protobuf-c's config template is config.h.in
        # (configure.ac:24, AC_CONFIG_HEADERS(config.h)). One configure
        # only: there is no AC_CONFIG_SUBDIRS, so the sweep below is the
        # only Makefile.in touch needed.
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
