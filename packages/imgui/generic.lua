require("imgui@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/imgui/* .
        # Dear ImGui ships no build system: no configure, no CMakeLists.txt,
        # no Makefile. The core library is four translation units that a
        # consumer either drops into its own build or archives itself, so the
        # objects are built with the system's $CXX/$CFLAGS and archived with
        # $AR, the same shape packages/lua/generic.lua uses for the same
        # reason.
        #
        # imgui_demo.cpp is example code and is not compiled. backends/ is 19
        # platform glue files, each of which needs a windowing or rendering
        # API that this prefix does not provide (X11, Wayland, DirectX, Metal,
        # SDL, Allegro, GLFW, ...) - imgui_impl_glfw.cpp would pair with the
        # glfw package, but only a consumer that has a window system can use
        # it. misc/freetype and misc/cpp are optional extras behind
        # IMGUI_ENABLE_FREETYPE / IMGUI_USE_STB_SPRINTF, neither of which is
        # defined here, so they are not needed; the in-tree imstb_*.h are
        # what imgui_draw.cpp actually includes.
        #
        # The core needs nothing from a host that is missing on these targets:
        # the only system headers its four sources include are <stdio.h>,
        # <stdint.h> and <time.h> (imgui.cpp:1252-1260), plus <stdint.h> in
        # imgui_draw.cpp/imgui_tables.cpp/imgui_widgets.cpp. The Windows,
        # Carbon and Mach-O headers are all behind _WIN32 or __APPLE__
        # (imgui.cpp:1261-1300) and never fire. The one platform call is
        # localtime_r() (imgui.cpp:4490), which Bionic has at every API level.
        mkdir -p obj $OUT/lib $OUT/include $OUT/lib/pkgconfig
        for _s in imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp; do
          $CXX $CXXFLAGS -c "$_s" -o "obj/${_s%.cpp}.o"
        done
        $AR rcs $OUT/lib/libimgui.a obj/*.o
        $RANLIB $OUT/lib/libimgui.a
        cp imgui.h imgui_internal.h imconfig.h imstb_rectpack.h imstb_textedit.h imstb_truetype.h LICENSE.txt $OUT/include/
        # Upstream ships no .pc and no CMake package config, so one is written
        # here, as packages/lua/generic.lua does.
        cat > $OUT/lib/pkgconfig/imgui.pc <<EOF
        prefix=$PREFIX
        exec_prefix=\${prefix}
        libdir=\${exec_prefix}/lib
        includedir=\${prefix}/include
        Name: imgui
        Description: Baked GUI library for C++ - Dear ImGui core
        Version: 1.92.9
        Libs: -L\${libdir} -limgui
        Cflags: -I\${includedir}
        EOF
    ]]
})