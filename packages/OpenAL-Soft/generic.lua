require("OpenAL-Soft@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/OpenAL-Soft/* .
        # Static, because a target prefix has no loader path for a versioned
        # .so. LIBTYPE defaults to SHARED (CMakeLists.txt:140-141), so this
        # must be explicit.
        #
        # The value is STATIC in UPPER CASE, and that matters: every test is
        # `LIBTYPE STREQUAL "STATIC"` (lines 311, 322, 329, 1173, 1207, 1323)
        # and cmake's STREQUAL is case-SENSITIVE, so -DLIBTYPE=Static silently
        # matches nothing. With it misspelled the build falls through to the
        # SHARED branch at line 1257 AND line 1173 stays false, so openal.pc
        # ships without -DAL_LIBTYPE_STATIC and every consumer that includes
        # the AL headers fails on the __declspec(dllimport) form. STATIC is
        # the only spelling that takes.
        # With it, AL_LIBTYPE_STATIC is set on the exported target (line 1209)
        # and -DAL_LIBTYPE_STATIC goes into openal.pc (line 1173-1174).
        #
        # Host programs and host-side files all off:
        # ALSOFT_UTILS - builds openal-info and alsoft-config
        # (add_subdirectory at line 1469);
        # ALSOFT_EXAMPLES - alplay, alstream and friends;
        # ALSOFT_INSTALL_EXAMPLES and ALSOFT_INSTALL_UTILS - the matching
        # install rules;
        # ALSOFT_INSTALL_CONFIG - alsoftrc.sample is a sample configuration
        # file, not something a library consumer needs;
        # ALSOFT_BUILD_IMPORT_LIB - defaults ON under MINGW and its own help
        # text says it "requires sed", which this tree forbids. It is already
        # skipped when LIBTYPE=STATIC (line 1323), and passing it OFF makes
        # that explicit rather than incidental.
        # ALSOFT_UPDATE_BUILD_VERSION=OFF so the build does not try to
        # re-derive a version from git, which a tag archive has no history for.
        #
        # DATA stays on: ALSOFT_INSTALL_HRTF_DATA and
        # ALSOFT_INSTALL_AMBDEC_PRESETS stay at their ON default
        # (lines 86-87) because the HRTF and AmbDec data is loaded by the
        # library at runtime from the prefix (install DIRECTORY at lines
        # 1402 and 1408). Dropping it would give a library that silently
        # loses spatial audio.
        cmake -S . -B build $CMAKE_FLAGS -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_INSTALL_EXAMPLES=OFF -DALSOFT_INSTALL_UTILS=OFF -DALSOFT_INSTALL_CONFIG=OFF -DALSOFT_BUILD_IMPORT_LIB=OFF -DALSOFT_UPDATE_BUILD_VERSION=OFF -DALSOFT_INSTALL_HRTF_DATA=ON -DALSOFT_INSTALL_AMBDEC_PRESETS=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
