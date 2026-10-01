require("physfs@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/physfs/* .
        # Static libphysfs.a, physfs.h, physfs.pc and a CMake package config.
        # PhysFS is a real C library: one abstraction layer over a set of VFS
        # archiver backends (CMakeLists.txt:93-113 PHYSFS_SRCS).
        #
        # Installed, exactly as upstream lays it out:
        #   lib/libphysfs.a                     CMakeLists.txt:148-171
        #   include/physfs.h                    CMakeLists.txt:225
        #   lib/cmake/PhysFS/PhysFSConfig.cmake  :227-231
        #   lib/pkgconfig/physfs.pc              :233-243
        #
        # PHYSFS_BUILD_SHARED=OFF: defaults TRUE (:175) and a target prefix
        # has no loader path for libphysfs.so.3.2.0. The static target is
        # physfs-static, whose OUTPUT_NAME is "physfs" on non-MSVC (:156), so
        # the installed file is libphysfs.a and physfs.pc's -lphysfs resolves
        # either way. On Windows the static library keeps its own name
        # (:152-156) so it cannot collide with the DLL's import library.
        #
        # PHYSFS_BUILD_TEST=OFF is load-bearing. It defaults TRUE (:199) and
        # :204-215 then does find_path for readline, find_library for curses,
        # and add_executable(test_physfs ...) - and, worse, appends it to
        # PHYSFS_INSTALL_TARGETS (:215), so an interactive terminal test
        # program would be INSTALLED into $PREFIX/bin. It is a host program
        # with no place in a target prefix.
        #
        # PHYSFS_BUILD_DOCS=OFF: defaults TRUE (:245) and reaches
        # find_package(Doxygen) / add_custom_target(docs ...). Doxygen is not
        # in this prefix; with it off the target is never created.
        #
        # Every archiver stays enabled, and that is the point worth stating:
        # there is no backend here that needs a display or makes a host-
        # filesystem assumption we cannot justify. PHYSFS_ARCHIVE_ZIP, _7Z,
        # _GRP, _WAD, _HOG, _MVL, _QPAK, _SLB, _ISO9660 and _VDF all default
        # TRUE (:116-146) and are pure C decoders over an in-memory buffer -
        # 7z and zip ship their own miniz/lzma decompressors
        # (src/physfs_miniz.h, src/physfs_lzmasdk.h) rather than looking for a
        # system zlib, so there is no external dependency to satisfy. The only
        # platform gate is CD-ROM support, and PhysFS disables it for Android
        # by itself at src/physfs_platforms.h:47 (PHYSFS_NO_CDROM_SUPPORT),
        # driven by __ANDROID__ from the NDK compiler wrapper.
        #
        # No android.lua: the Android platform backend is selected by the
        # compiler's own __ANDROID__ macro (src/physfs_platforms.h:43-47),
        # not by a build-system variable, so there is no Android-only switch
        # for a recipe to set.
        cmake -S . -B build $CMAKE_FLAGS -DPHYSFS_BUILD_STATIC=ON -DPHYSFS_BUILD_SHARED=OFF -DPHYSFS_BUILD_TEST=OFF -DPHYSFS_BUILD_DOCS=OFF -DPHYSFS_DISABLE_INSTALL=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
