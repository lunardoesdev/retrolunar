require("glfw@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/glfw/* .
        # This prefix has no X11, no Wayland and no display server at all, so
        # the two Unix backends are switched off. The point is that GLFW 3.5
        # can be built with no backend whatsoever: the null backend's sources
        # are unconditional members of the library target (src/CMakeLists.txt:8)
        # and src/platform.h:40 includes null_platform.h unconditionally,
        # while every real backend is gated behind an `#if defined(_GLFW_*)`
        # test that simply resolves to false. What X11 and Wayland contribute
        # on top is the probes, not the library:
        #   find_package(X11 REQUIRED) (src/CMakeLists.txt:176) plus five
        #   FATAL_ERRORs for the XRandR/Xinerama/Xkb/Xcursor/XInput headers
        #   (src/CMakeLists.txt:181,187,191,199,205,211), and for Wayland a
        #   FATAL_ERROR on a missing wayland-scanner host program
        #   (src/CMakeLists.txt:77). None of that exists on any target here.
        # The consequence is honest and worth stating: the installed library
        # creates no real window. At runtime it must be told
        #   glfwInitHint(GLFW_PLATFORM, GLFW_PLATFORM_NULL)
        # and then _glfwSelectPlatform takes the null path unconditionally
        # (src/platform.c:78-79), which is the one platform that is always
        # compiled in. Nothing here is a workaround - both are upstream's own
        # documented switches - but a consumer expecting a display is wrong.
        #
        # GLFW_BUILD_EXAMPLES and GLFW_BUILD_TESTS default to ON for a
        # standalone build (CMakeLists.txt:10-11); they are 25 host programs
        # between them and must not be cross-compiled. GLFW_BUILD_DOCS
        # defaults ON (CMakeLists.txt:12) and needs Doxygen >= 1.9.8
        # (docs/CMakeLists.txt:3), a host tool nothing here guarantees.
        # BUILD_SHARED_LIBS is already the upstream default OFF
        # (CMakeLists.txt:9); passed explicitly because a target prefix has
        # no loader path for a versioned object.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DGLFW_BUILD_X11=OFF -DGLFW_BUILD_WAYLAND=OFF -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})