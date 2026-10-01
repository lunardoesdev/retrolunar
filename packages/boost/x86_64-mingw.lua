-- Why this file exists, and why it is not a copy of generic.lua.
--
-- generic.lua installs Boost's headers and its CMake package config, and
-- nothing else. That is enough for CGAL and is deliberately cheap. It is
-- NOT enough for any package that calls
--     find_package(Boost REQUIRED COMPONENTS ...)
-- because a compiled component only exists as (a) an archive in lib/ and
-- (b) a component package config in lib/cmake/<name>-<version>/. With
-- headers alone, `boost_headers` resolves and the component lookup fails:
--
--   CMake Error at .../BoostConfig.cmake:126 (find_package):
--     Could not find a package configuration file provided by
--     "boost_filesystem" (requested version 1.92.0)
--
-- i2pd is that package: build/CMakeLists.txt:289 is
--     find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)
-- so boost@x86_64-mingw has to produce all three. This is not a per-target
-- copy of an Android recipe: there is exactly one mingw system, and this
-- file differs from generic.lua in what it builds, not in how.
--
-- The component list is the whole point, so it is spelled out:
--   - atomic         build/CMakeLists.txt:289
--   - filesystem     :289, and libi2pd/FS.cpp + libi2pd_client/AddressBook.cpp
--   - program_options:289, and libi2pd/Config.cpp
-- b2 pulls in `container` on its own as a dependency of filesystem
-- (libs/filesystem/build/Jamfile.v2 requires /boost/container); it is
-- installed and that is correct, not an accident.
--
-- OTHER SYSTEMS STILL TAKE generic.lua, so i2pd remains blocked on Android
-- until a compiled Boost is proven there. packages/boost/stage1.md:295-301
-- already records that nothing in this tree is evidence that a compiled
-- Boost builds on android21, so that gap is left visible rather than
-- papered over.
require("boost@native")
require("boost@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/boost/* .

        # b2 DOES NOT READ $CC/$CXX/$AR. It reads its own `using` lines, and
        # with none it prints
        #     warning: Configuring default toolset "gcc".
        # and builds for the BUILD MACHINE -- which is how a cross build
        # silently produces host objects.
        #
        # The file is written here and named EXPLICITLY with --user-config,
        # because b2 does not look for it in the current directory. That is
        # not a guess: build-system.jam:443-463 loads user-config.jam from
        # $(user-path), which is $HOME/.b2. Probed here with the `using` line
        # sitting in the CWD -- b2 printed "No toolsets are configured" and
        # planned host-Linux paths; the same tree with --user-config on the
        # command line planned target-os-windows paths immediately. `toolset=gcc`
        # is on the command line too, so a config that still fails to load
        # becomes a hard error rather than a silent host build.
        #
        # The command is $CXX (the C++ driver), not $CC. That is not a
        # preference. gcc.jam:163 uses the single `command` for BOTH languages
        # and gcc.jam:248 derives the archiver from it; b2 never adds
        # `-lstdc++` itself. Hand it `...-gcc` and every C++ link fails with
        #     undefined reference to `operator new(unsigned long long)'
        #     undefined reference to `__gxx_personality_seh0'
        # because the C driver does not pull in the C++ runtime. Probed both
        # ways on this host: the `gcc` spelling fails, `g++` links clean.
        cat > user-config.jam <<EOF
        using gcc : : $CXX : <archiver>$AR <ranlib>$RANLIB ;
        EOF

        # -j1 is explicit: b2 defaults to serial, and this must not fan out.
        # --layout=system is passed rather than inferred, because
        # boostcpp.jam:84-94 picks the layout from os.name, the BUILD
        # machine's OS, which is Linux here even though the target is
        # Windows. `system` is what puts headers at include/boost/ and the
        # archives at lib/, which is where $PREFIX/include and $PREFIX/lib
        # look; `versioned` would give include/boost-1_92_0/ and a consumer
        # passing -I$PREFIX/include would find nothing.
        b2 --user-config=user-config.jam toolset=gcc -d0 -j1 \
            --layout=system --prefix="$OUT" \
            --with-atomic --with-filesystem --with-program_options \
            install
    ]]
})