return recipe({
    version = "1.10.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lz4.tar.gz ]; then
          curl -fSL -C - -o dl/lz4.tar.gz "https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lz4.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lz4
        cp -r src/* $OUT/lz4/
    ]]
})
