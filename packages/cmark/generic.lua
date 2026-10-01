require("cmark@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cmark/* .
        # Static libcmark, cmark.h and cmark_ctype.h, libcmark.pc and a CMake
        # package config under lib/cmake/cmark.
        #
        # cmark 0.31.2 has NO autotools: the release ships CMakeLists.txt, a
        # hand-written Makefile, Makefile.nmake and nmake.bat, and there is no
        # configure, configure.ac or Makefile.am anywhere in the tarball. So
        # this is CMake, and there is no timestamp guard to write.
        #
        # BUILD_TESTING=OFF is load-bearing. CMakeLists.txt:20 does
        # include(CTest), which defaults BUILD_TESTING to ON, and :117-120 then
        # adds api_test and test/ as host programs that link the test suite and
        # run it. On a cross build those are target binaries that can never be
        # run here. Upstream ships no cmark-specific test switch, so
        # BUILD_TESTING is the only lever.
        #
        # BUILD_SHARED_LIBS=OFF: the standard switch. cmark still accepts the
        # old CMARK_SHARED/CMARK_STATIC names but warns about them as
        # deprecated (CMakeLists.txt:36-52).
        #
        # CMARK_LIB_FUZZER is already OFF and stays off: it would add -fsanitize
        # =fuzzer flags (CMakeLists.txt:100-108) and add_subdirectory(fuzz).
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})