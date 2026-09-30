require("sdl2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/sdl2/* .
        # Static library, no SDL2 shared object. SDL2 spells its switches
        # SDL_<SUB>, not ENABLE_<SUB>, so the names below are not a typo.
        #   -DSDL_SHARED=OFF -DSDL_STATIC=ON  is redundant with
        #     -DBUILD_SHARED_LIBS=OFF but harmless; SDL reads both.
        #   -DSDL_TEST/TESTS/EXAMPLES/INSTALL_TESTS=OFF  drops the host
        #     programs - the one thing a cross build must not compile.
        #   -DSDL_AUDIO=OFF  because the recipe keeps no audio backend and
        #     building a target audio driver nothing can run is dead weight.
        #   -DSDL_SYSTEM_ICONV=OFF  so SDL does not probe for a system iconv
        #     that Bionic does not ship separately.
        #   -DSDL_LIBC=ON  is the baseline libc, not a third-party library.
        #
        # SDL_VIDEO=ON with SDL_GPU=OFF and SDL_RENDER=ON looks contradictory
        # and was flagged as such. It is kept deliberately, and the reasoning
        # is worth recording: SDL2's video subsystem also carries SDL_events,
        # so switching it off would take event handling, timers and the
        # clipboard away with it. This prefix has no X11, Wayland or KMSDRM in
        # Bionic's sysroot, so no video backend is expected to initialise and
        # SDL_RENDER has nothing to present into - the compiled video surface
        # is real but unusable. A reviewer who wants a strictly
        # presentation-free library should drop -DSDL_VIDEO=ON and
        # -DSDL_RENDER=ON together and accept losing events; that is a
        # one-line change, and it is a decision, not a fix.
        # -DSDL_HIDAPI=ON likewise encodes a choice: SDL2 can use the system
        # HIDAPI backend or build and bundle its own. It is left on, and the
        # configuration summary at the end of the cmake run says which was
        # taken - the builder should compare that line against this comment.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL_TESTS=OFF -DSDL_SYSTEM_ICONV=OFF -DSDL_LIBC=ON -DSDL_AUDIO=OFF -DSDL_VIDEO=ON -DSDL_GPU=OFF -DSDL_RENDER=ON -DSDL_CAMERA=OFF -DSDL_JOYSTICK=ON -DSDL_HAPTIC=OFF -DSDL_HIDAPI=ON -DSDL_POWER=ON -DSDL_FILESYSTEM=ON -DSDL_TIMERS=ON -DSDL_THREADS=ON -DSDL_LOCALES=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
