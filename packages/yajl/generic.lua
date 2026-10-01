require("yajl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/yajl/* .
        # NOTE: this package does NOT configure in this tree, on any system.
        # yajl 2.1.0's top-level CMakeLists.txt:66-71 adds six
        # subdirectories with no option to suppress any of them, and
        # reformatter/CMakeLists.txt:38 and verify/CMakeLists.txt:32 both do
        # GET_TARGET_PROPERTY(... LOCATION), which cmake deprecated in 3.19
        # and turned into a hard error in 4.x. Configure therefore dies
        # before a single target exists, so nothing downstream runs.
        #
        # There is no recipe-level fix and no flag. The escape hatch would be
        # a cmake older than 3.19 in the prefix, which belongs in the system
        # files, not here. See stage1.md; this recipe is kept intact and
        # correct so that it works unchanged if the toolchain question is
        # ever settled, but it is expected to fail at the cmake line below.
        #
        # The build is left as a plain full build rather than the
        # target-scoped `--target yajl_s` an earlier version used: yajl's
        # src/CMakeLists.txt:80 has an UNCONDITIONAL
        # INSTALL(TARGETS yajl ...), so a build that skipped the shared
        # `yajl` target would leave cmake --install with a rule for a file
        # that does not exist, and install(TARGETS) on a missing artefact
        # fails. Building everything avoids that second failure.
        cmake -S . -B build $CMAKE_FLAGS
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
