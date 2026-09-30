require("zlib")
require("bzip2")
require("xz")
require("opus")
require("libvpx")
require("lame")
require("ffmpeg@source")

-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe. The host machine comes from
-- the system as $HOST_ARCH/$HOST_OS; ffmpeg spells two of the arches
-- differently, which the case below handles.
return recipe({
    build = [[
        cp -r $NESTDIR/source/ffmpeg/* .
        case "$HOST_ARCH" in
            armv7a) ffmpeg_arch=arm ;;
            i686) ffmpeg_arch=x86 ;;
            *) ffmpeg_arch="$HOST_ARCH" ;;
        esac
        # Cross builds must be told the host: ffmpeg would otherwise assume
        # the build machine, and Bionic needs -DANDROID, which this system's
        # $CFLAGS already carries (ffmpeg ignores $CFLAGS on its own).
        ./configure --prefix="$OUT" --enable-cross-compile --arch="$ffmpeg_arch" --target-os="$HOST_OS" --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config-flags="--static" --enable-static --disable-shared --disable-doc --disable-programs --disable-network --disable-iconv --disable-libxcb --enable-zlib --enable-bzlib --enable-lzma --enable-libopus --enable-libvpx --enable-libmp3lame --enable-pic --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
        make -j1
        make install
    ]]
})
