require("easylogging-plusplus@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/easylogging-plusplus/* .
        # Header-only C++ logging library. build_static_lib defaults OFF
        # (CMakeLists.txt:25), so nothing is compiled and the install is a
        # file copy identical on every system. cmake runs only to drive the
        # install rules and to generate easyloggingpp.pc.
        #
        # Installed, exactly as upstream lays it out:
        #   include/easylogging++.h   CMakeLists.txt:38-42
        #   include/easylogging++.cc   CMakeLists.txt:38-42
        #   share/pkgconfig/easyloggingpp.pc   :44-47
        # There is NO CMake package config. CMakeLists.txt:69 is a bare
        # `export(PACKAGE Easyloggingpp)`, which writes nothing into $OUT -
        # there is no install(EXPORT) and no Config.cmake.in in the tree.
        # The pkg-config file is therefore the only discovery mechanism, which
        # is worth knowing before looking for a CMake config that is not there.
        #
        # Note the layout: the header AND its implementation land side by side
        # in include/, because easylogging++ is the split-header form (the
        # library was separated into .h/.cc - see ACKNOWLEDGEMENTS.md). A
        # consumer compiles easylogging++.cc into their own program rather
        # than linking a library from this prefix.
        #
        # test=OFF: already the default (CMakeLists.txt:24), passed
        # explicitly for the same reason as the others. With it ON, :78 does
        # find_package(GTest REQUIRED) and :87-100 builds a test executable -
        # a host program with no place in a target prefix.
        #
        # lib_utc_datetime stays OFF (:26, default). It only adds
        # -DELPP_UTC_DATETIME to THIS build's compile line (:57), and since
        # build_static_lib is off there is nothing to compile; a consumer who
        # wants UTC logging defines it themselves.
        #
        # cmake_minimum_required is 2.8.7 (CMakeLists.txt:1), far below the
        # cmake 4.x floor, which $CMAKE_FLAGS handles with
        # -DCMAKE_POLICY_VERSION_MINIMUM=3.5.
        cmake -S . -B build $CMAKE_FLAGS -Dbuild_static_lib=OFF -Dtest=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
