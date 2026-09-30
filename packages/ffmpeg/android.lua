require("zlib")
require("bzip2")
require("xz")
require("opus")
require("libvpx")
require("lame")
require("ffmpeg@source")

-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe. The target identity comes from
-- the system: $TARGET_ARCH and $TARGET_OS are ffmpeg's own spellings of this
-- system's architecture and OS.
return recipe({
    build = [[
        cp -r $NESTDIR/source/ffmpeg/* .
        # Cross builds must be told the target: ffmpeg would otherwise assume
        # the host, and Bionic needs -DANDROID, which this system's $CFLAGS
        # already carries (ffmpeg ignores $CFLAGS on its own).
        ./configure --prefix="$OUT" --enable-cross-compile --arch="$TARGET_ARCH" --target-os="$TARGET_OS" --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config-flags="--static" --enable-static --disable-shared --disable-doc --disable-programs --disable-network --disable-iconv --disable-libxcb --enable-zlib --enable-bzlib --enable-lzma --enable-libopus --enable-libvpx --enable-libmp3lame --enable-pic --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
        make -j1
        make install
    ]]
})
