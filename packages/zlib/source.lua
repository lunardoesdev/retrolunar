return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zlib.tar.gz ]; then
          curl -fSL -C - -o dl/zlib.tar.gz "https://zlib.net/fossils/zlib-1.3.1.tar.gz" || curl -fSL -C - -o dl/zlib.tar.gz "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zlib.tar.gz -C src --strip-components=1
        mkdir -p $OUT/zlib
        cp -r src/* $OUT/zlib/
    ]]
})
