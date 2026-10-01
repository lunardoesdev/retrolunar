require("astyle@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/astyle/* .
        # Upstream is CMake-only: the release ships no configure, no
        # configure.ac and no Makefile that we drive. cmake_minimum_required
        # (VERSION 3.10) at CMakeLists.txt:1, project(astyle CXX) at :7.
        #
        # BUILD_SHARED_LIBS is stated explicitly rather than left implicit.
        # It is OFF by default (:11), and that is what we want: with all
        # three of BUILD_SHARED_LIBS / BUILD_STATIC_LIBS / BUILD_JAVA_LIBS
        # off, CMakeLists.txt:47-51 takes the add_executable(astyle ...) arm
        # instead of add_library. Turning it on would silently turn this
        # package from a command-line tool into a library.
        #
        # The compiler standard is not something we have to pass:
        # CMakeLists.txt:19 sets CMAKE_CXX_STANDARD 17 outright.
        # CMakeLists.txt:15-17 defaults CMAKE_BUILD_TYPE to Release.
        #
        # Nothing outside $PREFIX is searched for: the sources are a plain
        # file(GLOB SRCS src/*.cpp) at CMakeLists.txt:28 with no
        # find_package anywhere in the file.
        #
        # NOT BUILT ON x86_64-mingw: CMakeLists.txt:143-150 installs through
        # its elseif(WIN32) arm, to "${prog_files}/AStyle" where prog_files
        # comes from $ENV{PROGRAMFILES(x86)} with $ENV{PROGRAMFILES} as
        # fallback (:144-147). That destination is an absolute path outside
        # CMAKE_INSTALL_PREFIX, so `cmake --install --prefix $OUT` cannot
        # redirect it, and when this prefix is built from Linux neither
        # PROGRAMFILES variable is set, so it collapses to "/AStyle". The
        # install step would then write outside $OUT (or fail on
        # permissions) and nothing would be published. The non-Windows arm at
        # :157-167, which does honour CMAKE_INSTALL_PREFIX, is unreachable
        # on mingw because CMake sets WIN32 for MinGW. Recorded as
        # WILL NOT BUILD in stage1.md; no workaround is invented here.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})