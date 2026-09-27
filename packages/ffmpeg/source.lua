return recipe({
    version = "7.1.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ffmpeg.tar.xz ]; then
          curl -fSL -C - -o dl/ffmpeg.tar.xz "https://ffmpeg.org/releases/ffmpeg-7.1.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/ffmpeg.tar.xz -C src --strip-components=1
        mkdir -p $OUT/ffmpeg
        cp -r src/* $OUT/ffmpeg/
    ]]
})
