return recipe({
    version = "1.5.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/flac.tar.xz ]; then
          curl -fSL -C - -o dl/flac.tar.xz "https://downloads.xiph.org/releases/flac/flac-1.5.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/flac.tar.xz -C src --strip-components=1
        mkdir -p $OUT/flac
        cp -r src/* $OUT/flac/
    ]]
})
