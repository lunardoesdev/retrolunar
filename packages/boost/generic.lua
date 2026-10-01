-- Why there is no boost@native requirement any more.
--
-- This file used to build Boost with b2 and needed the b2 engine, which is a
-- PROGRAM that must run on this machine to drive the build (bootstrap.sh:229
-- deliberately clears $CXX so the engine is built by the host compiler). That
-- is why boost/clang-native.lua existed, and why the cross systems' exported
-- WINDRES could reach a host build and link a PE resource object into it.
--
-- The build is cmake now, so there is no b2, no engine to cross-compile, and
-- no host helper at all. boost/clang-native.lua is deleted; this file is the
-- whole build, and it is the same for every system because cmake takes the
-- toolchain from $CMAKE_FLAGS.
--
-- WHAT IS BUILT, and why these three libraries.
--
-- Boost 1.92 ships no top-level CMakeLists.txt, so packages/boost/
-- CMakeLists.txt is ours: a project() call, the 38-library dependency
-- closure, the unified-layout include fix, and the boost_install() call.
-- Every archive, package config and version file is produced by upstream's
-- own tools/cmake/include/BoostInstall.cmake. That file's header explains why
-- the caller is needed at all, with the evidence.
--
-- The three compiled libraries are the ones i2pd asks for at
-- build/CMakeLists.txt:289:
--     find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)
-- A headers-only Boost cannot satisfy that: boost_headers resolves and the
-- component lookup then fails with "Could not find a package configuration
-- file provided by boost_filesystem". container comes along because
-- filesystem depends on it (libs/filesystem/CMakeLists.txt:228-244).
--
-- The headers still install, for header-only consumers such as CGAL, which
-- needs boost/version.hpp and a package config and nothing else.
require("boost@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/boost/* .

        # Our superproject is a file of OURS, not upstream's: it sits next to
        # this recipe rather than in the tarball, so it has to be copied into
        # the work directory. Same shape as the systems' cmake toolchain file
        # and meson crossfile, which are referenced as $SYSDIR/<file> rather
        # than generated as a heredoc.
        cp $RECIPEDIR/CMakeLists.txt .

        # $CMAKE_FLAGS carries the toolchain file, the install prefix and the
        # prefix path, and the systems already put the compiler there too
        # (packages/x86_64-mingw/x86_64-w64-mingw32-toolchain.cmake:10-16
        # reads $CC/$CXX from the environment). So no target fact is named
        # here: one recipe covers mingw, all four Android architectures and
        # clang-native.
        cmake -S . -B build $CMAKE_FLAGS
        cmake --build build --parallel 1
        cmake --install build
    ]]
})