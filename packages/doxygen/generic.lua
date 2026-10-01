require("doxygen@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/doxygen/* .
        # CMake-only as of 1.18: the release ships no configure and no
        # configure.ac at all, so there is no autotools timestamp guard.
        # cmake_minimum_required(VERSION 3.14) (CMakeLists.txt:14).
        #
        # build_wizard is the Qt6 GUI frontend; option(build_wizard ...) is
        # OFF by default (CMakeLists.txt:19) and this prefix has no Qt, so it
        # is stated explicitly rather than left implicit. build_doc builds the
        # HTML/PDF user manual, which needs LaTeX (CMakeLists.txt:23); also
        # OFF by default and stated for the same reason. The real
        # documentation generator we want is simply the doxygen binary
        # itself, installed by src/CMakeLists.txt:417 as DESTINATION bin.
        #
        # Everything the build shells out to is a HOST tool, which is correct
        # on a cross build: find_package(FLEX REQUIRED) (CMakeLists.txt:249,
        # needs >= 2.5.37) and find_package(BISON REQUIRED) (:259, needs >= 2.7)
        # generate the lexer and parser that are then COMPILED for the target,
        # and find_package(Python REQUIRED) (:248) runs the configgen.py,
        # res2cc_cmd.py, scan_states.py and post_lex.py steps in
        # src/CMakeLists.txt. cmake finds them on the build machine's PATH,
        # which our cross systems deliberately do not overwrite with the
        # target toolchain. Nothing here executes a target binary.
        #
        # fmt, spdlog and sqlite3 are vendored under deps/, not fetched:
        # use_sys_spdlog/use_sys_fmt/use_sys_sqlite3 all default OFF
        # (CMakeLists.txt:29-31) and there is no FetchContent or
        # ExternalProject anywhere in the build, so no network is touched at
        # build time.
        cmake -S . -B build $CMAKE_FLAGS -Dbuild_wizard=OFF -Dbuild_doc=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})