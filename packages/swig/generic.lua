require("pcre2")
require("swig@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/swig/* .
        # WHAT SWIG IS, AND WHY IT IS A HOST TOOL IN PRACTICE.
        #
        # swig is a code generator. It reads C/C++ headers and emits a
        # .cxx wrapper that the CONSUMER's build then compiles and links into
        # the target. Nothing swig itself produces is linked into the target
        # at build time: the only artifacts are the `swig` executable and
        # Lib/*.swg (pure interface files, architecture independent), both
        # installed here by CMakeLists.txt:149 (the executable) and :120 (the
        # interface library).
        #
        # So `swig` has to RUN on the machine doing the build, never on the
        # target. In this tree that is what $NATIVE_PREFIX is for, exactly as
        # it is for meson: a consumer should `require("swig@native")`, never
        # `require("swig")`. This recipe is deliberately system-neutral and
        # will cross-compile a perfectly good target-side binary on every
        # system below, but that binary is of niche value -- it is the
        # clang-native copy that other recipes could actually use.
        #
        # BUILD SYSTEM: cmake, not autotools, and the reason is concrete.
        # This release ships NO generated `configure` -- verified by listing,
        # not assumed -- only configure.ac (89027 bytes). Worse for the
        # autotools path, the template configure.ac:10 declares,
        # AC_CONFIG_HEADERS([Source/Include/swigconfig.h.in]), does not ship
        # either; the tree contains only Tools/cmake/swigconfig.h.in, which
        # is the *cmake* project's template. Getting autotools to work would
        # mean running autoheader to invent the missing template. The cmake
        # build generates that header from Tools/cmake/swigconfig.h.in at
        # CMakeLists.txt:84-85 instead, so no autotools timestamp guard is
        # needed at all.
        #
        # PCRE2 is a hard dependency, not an optional nicety:
        # option(WITH_PCRE "Enable PCRE" ON) at CMakeLists.txt:73 and then
        # find_package(PCRE2 REQUIRED COMPONENTS 8BIT) at :76. Turning it
        # off with -DWITH_PCRE=OFF would silently drop the regex support
        # swigwarn and the preprocessor use, so this requires pcre2 from the
        # prefix instead and lets cmake find it through the system's
        # CMAKE_PREFIX_PATH and PKG_CONFIG_LIBDIR. The comment at :75 notes
        # swig only needs the PCRE2 API available since 10.00, which is well
        # below the 10.45 this prefix pins.
        #
        # bison is a HOST tool and is correct as one:
        # find_package(BISON 3.5 REQUIRED) at :87 runs BISON_TARGET (:108-111)
        # to generate Source/CParse/parser.c on the build machine, which is
        # then compiled for the target. Our cross systems deliberately leave
        # PATH pointing at the host toolchain, so cmake finds the host bison.
        # No python3 is needed: nothing in CMakeLists.txt looks for one.
        cmake -S . -B build $CMAKE_FLAGS -DWITH_PCRE=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})