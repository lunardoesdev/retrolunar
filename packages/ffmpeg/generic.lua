require("zlib")
require("bzip2")
require("xz")
require("opus")
require("libvpx")
require("lame")
require("ffmpeg@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ffmpeg/* .
        # ffmpeg's configure is hand-written (libav-style) and ignores
        # $CFLAGS/$LDFLAGS, so the system's flags go in explicitly.
        # Cross targets need --arch/--target-os and cannot guess the target;
        # they are served by android.lua (and any other family file), which
        # reads $HOST_ARCH/$HOST_OS from the system.
        ./configure --prefix="$OUT" --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config-flags="--static" --enable-static --disable-shared --disable-doc --disable-programs --disable-network --disable-iconv --disable-libxcb --enable-zlib --enable-bzlib --enable-lzma --enable-libopus --enable-libvpx --enable-libmp3lame --enable-pic --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
        make -j1
        make install
    ]]
})
