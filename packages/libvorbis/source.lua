return recipe({
    version = "1.3.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libvorbis.tar.gz ]; then
          curl -fSL -C - -o dl/libvorbis.tar.gz "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libvorbis.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libvorbis
        cp -r src/* $OUT/libvorbis/
    ]]
})
