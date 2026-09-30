return recipe({
    version = "1.3.5",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libogg.tar.gz ]; then
          curl -fSL -C - -o dl/libogg.tar.gz "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libogg.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libogg
        cp -r src/* $OUT/libogg/
    ]]
})
