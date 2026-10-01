require("libjpeg-turbo")
require("jasper@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/jasper/* .
        # Static libjasper. jasper's own codecs (bmp, jp2, jpc, pgx, pnm,
        # mif, ras) need no external library and are left on; the JPEG codec
        # uses the libjpeg-turbo in this prefix, found through
        # CMAKE_PREFIX_PATH. The four switches turn off what this prefix
        # cannot provide or does not want:
        #   JAS_ENABLE_SHARED=OFF  a target prefix takes the archive.
        #   JAS_ENABLE_LIBHEIF=OFF  libheif is not in this prefix at all;
        #                           CMakeLists.txt:792-804 would silently
        #                           set JAS_INCLUDE_HEIC_CODEC to 0 anyway,
        #                           so passing it makes the intent explicit.
        #   JAS_ENABLE_OPENGL=OFF  find_package(OpenGL)/find_package(GLUT)
        #                           at CMakeLists.txt:717-718 have nothing to
        #                           find on Android or in this prefix.
        #   JAS_ENABLE_PROGRAMS=OFF and JAS_ENABLE_DOC=OFF are host-side.
        # JAS_STRICT defaults OFF, so warnings are not fatal here.
        cmake -S . -B build $CMAKE_FLAGS \
            -DJAS_ENABLE_SHARED=OFF \
            -DJAS_ENABLE_LIBJPEG=ON \
            -DJAS_ENABLE_LIBHEIF=OFF \
            -DJAS_ENABLE_OPENGL=OFF \
            -DJAS_ENABLE_PROGRAMS=OFF \
            -DJAS_ENABLE_DOC=OFF \
            -DJAS_ENABLE_LATEX=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
