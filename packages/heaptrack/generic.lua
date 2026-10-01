-- heaptrack WILL NOT BUILD in this prefix. It is a KDE/Qt application and
-- there is no Qt here: packages/ contains no qt, qt5, qt6 or base, which was
-- checked by listing, not assumed. Everything below is therefore written to
-- be correct in shape but is NOT expected to configure. See stage1.md.
--
-- The one thing that would make this build is a Qt 6 package in this prefix.
-- It deliberately does NOT `require("qt6")`: the loader would fail at
-- require() time with a package-not-found error, which hides the real reason
-- and produces a worse diagnostic than the configure failure below.
--
-- The Qt component list has NOT been verified against upstream's build files.
-- The release archive could not be fetched (see source.lua and stage1.md), so
-- no component names are guessed here.
require("heaptrack@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/heaptrack/* .
        # Generic cmake invocation only. No project-specific -D option is
        # passed, because none could be verified against the upstream build
        # files -- inventing option names is worse than omitting them, and an
        # unrecognised -D would be silently ignored by cmake.
        #
        # Expect `find_package(Qt6 ... REQUIRED)` to fail here. That is the
        # recorded blocker, not a defect in this recipe.
        cmake -S . -B build $CMAKE_FLAGS
        cmake --build build --parallel 1
        cmake --install build
    ]]
})