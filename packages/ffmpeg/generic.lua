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
        ./configure --prefix="$OUT" --enable-cross-compile --arch=aarch64 --target-os=android --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config-flags="--static" --enable-static --disable-shared --disable-doc --disable-programs --disable-network --disable-iconv --disable-libxcb --enable-zlib --enable-bzlib --enable-lzma --enable-libopus --enable-libvpx --enable-libmp3lame --enable-pic --extra-cflags="-I$PREFIX/include -DANDROID" --extra-ldflags="-L$PREFIX/lib"
        make -j1
        make install
    ]]
})
