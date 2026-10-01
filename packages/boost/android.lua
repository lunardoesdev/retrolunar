-- Why this file exists, and why it is not a copy of generic.lua.
--
-- generic.lua installs Boost's headers and its CMake package config, and
-- nothing else. That is enough for CGAL and is deliberately cheap. It is
-- NOT enough for any package that calls
--     find_package(Boost REQUIRED COMPONENTS ...)
-- because a compiled component only exists as (a) an archive or import
-- library in lib/ and (b) a component package config in
-- lib/cmake/<name>-<version>/. With headers alone, `boost_headers` resolves
-- and the component lookup fails:
--
--   CMake Error at .../BoostConfig.cmake:126 (find_package):
--     Could not find a package configuration file provided by
--     "boost_filesystem" (requested version 1.92.0)
--
-- i2pd is that package: build/CMakeLists.txt:289 is
--     find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)
--
-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe. This is the packages/openssl/
-- android.lua shape: one file, per FAMILY, driven by $HOST_ARCH and the NDK
-- tools the system already exports.
--
-- WHAT IS STILL UNPROVEN: packages/boost/stage1.md:295-301 warned that
-- nothing in this tree was evidence that a COMPILED Boost builds on Android.
-- That warning is now narrower -- this recipe builds, and it was verified on
-- aarch64-android35 -- but the other three architectures and every other API
-- level still take their own run. b2 derives <architecture> from the driver
-- (`clang -dumpmachine`), so armv7a, i686 and x86_64 need no case here, but
-- "derives itself" is not "verified", and this file should not be read as
-- claiming more systems than have actually been built.
require("boost@native")
require("boost@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/boost/* .

        # b2 DOES NOT READ $CC/$CXX/$AR. It reads its own `using` lines, and
        # with none it prints
        #     warning: Configuring default toolset "clang".
        # and builds for the BUILD MACHINE -- which is how a cross build
        # silently produces host objects.
        #
        # The file is written here and named EXPLICITLY with --user-config,
        # because b2 does not look for it in the current directory:
        # build-system.jam:443-463 loads user-config.jam from $(user-path),
        # which is $HOME/.b2. Probed here with the `using` line sitting in
        # the CWD -- b2 printed "No toolsets are configured" and planned host
        # paths; the same tree with --user-config planned clang-linux-19 for
        # arm_64 immediately.
        #
        # `using clang`, not `using gcc`. On this host
        # tools/build/src/tools/clang.jam:18-38 dispatches by [ os.name ],
        # and Linux routes to clang-linux.jam:66, which takes
        #     ( version ? : command * : options * )
        # -- there is no separate archiver positional, unlike gcc.jam. The
        # archiver is an <archiver> option (clang-linux.jam:106-116) and
        # defaults to llvm-ar found next to the driver. Probed with the
        # archiver passed positionally as well, clang.jam:33 forwards four
        # arguments and clang-linux.jam:66 rejects the fourth:
        #     error: extra argument <ranlib>.../llvm-ranlib
        #
        # $CXX and not $CC, same reason as packages/boost/x86_64-mingw.lua:
        # one command drives both languages and b2 never adds -lstdc++.
        # Here it also matters that the NDK's C driver is named `-clang` and
        # its C++ one `-clang++`; passing the C++ driver is what makes the
        # `<threading>multi` and C++ standard flags come out right.
        # <triple> is the load-bearing option and the whole reason this
        # recipe differs from the mingw one beyond the toolset name.
        # Without it, clang.jam:113-117 calls init-flags-cross, which derives
        # a generic triple from the detected architecture and passes it as
        # `--target=arm64-pc-linux`. That OVERRIDES the NDK wrapper's own
        # triple, so the driver stops knowing it is an Android target, never
        # adds the NDK sysroot or libc++ include paths, and every C++
        # compile dies on
        #     ./boost/config/detail/select_stdlib_config.hpp:26:14:
        #       fatal error: 'cstddef' file not found
        # Verified both ways against the NDK 28.2.13676358 driver:
        #   $CXX --target=arm64-pc-linux       /tmp/c.cpp  -> cstddef not found
        #   $CXX --target=aarch64-linux-android35 /tmp/c.cpp -> exit 0
        # clang-linux.jam:79 reads <triple> and clang.jam:105 turns it into
        # `--target=`; passing it suppresses the guessed one entirely.
        #
        # $ANDROID_API is appended to $HOST_TRIPLET, and that is not
        # cosmetic. A bare Android triple carries no API level and the NDK
        # resolves it to the MINIMUM it supports, 21 -- so
        # `aarch64-linux-android` would silently pin the build to API 21
        # while the system says 35. Probed, and the difference is exactly the
        # wall i2pd hits at 21:
        #   --target=aarch64-linux-android    -> getifaddrs MISSING (API 21)
        #   --target=aarch64-linux-android35  -> getifaddrs OK
        # Bionic declares getifaddrs __INTRODUCED_IN(24). Concatenation is
        # uniform across the four arches -- aarch64-linux-android35,
        # armv7a-linux-androideabi35, i686-linux-android35 and
        # x86_64-linux-android35 all configure and compile against their
        # respective NDK wrappers.
        cat > user-config.jam <<EOF
        using clang : : $CXX : <archiver>$AR <triple>$HOST_TRIPLET$ANDROID_API ;
        EOF

        # -j1 is explicit: b2 defaults to serial, and this must not fan out.
        # --layout=system is passed rather than inferred, because
        # boostcpp.jam:84-94 picks the layout from os.name, the BUILD
        # machine's OS (always Linux here), not the target's. `system` puts
        # headers at include/boost/ and the archives at lib/, which is where
        # $PREFIX/include and $PREFIX/lib look.
        # target-os=android, and this is a first-class b2 value, not a
        # workaround: tools/build/src/tools/features/os-feature.jam:12 lists
        # android among the declared target-os values and :95 declares the
        # feature as propagated link-incompatible, so it selects library
        # naming and linking rules for the target.
        #
        # Without it b2 believes it is building for glibc Linux and adds -lrt
        # to shared links. Bionic has no librt at all -- the NDK sysroot
        # directory for aarch64-linux-android/35 contains libdl.so but no
        # librt.so -- so every shared link dies with
        #     ld.lld: error: unable to find library -lrt
        # and because the archive never appears, the component package
        # config is skipped too. This matters for i2pd, not just for tidiness:
        # WITH_STATIC=OFF (the default) makes build/CMakeLists.txt:282 define
        # BOOST_*_DYN_LINK, so the consumer wants the shared variant.
        b2 --user-config=user-config.jam toolset=clang -d0 -j1 \
            target-os=android --layout=system --prefix="$OUT" \
            --with-atomic --with-filesystem --with-program_options \
            install
    ]]
})