require("stb@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/stb/* .
        # stb ships no build system at all: no configure, no CMakeLists.txt,
        # no Makefile. Each library is one self-contained header that a
        # consumer instantiates with a #define, so there is nothing to
        # compile and no architecture to check. The install copies the headers
        # and the licence into $PREFIX/include, which is identical on every
        # system. Upstream ships no pkg-config file and no CMake package
        # config, so consumers just add -I$PREFIX/include and include
        # <stb_image.h> and friends.
        mkdir -p $OUT/include
        cp stb*.h stb_vorbis.c LICENSE $OUT/include/
    ]]
})
