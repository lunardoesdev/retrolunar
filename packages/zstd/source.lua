return recipe({
    version = "1.5.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zstd.tar.gz ]; then
          curl -fSL -C - -o dl/zstd.tar.gz "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zstd.tar.gz -C src --strip-components=1
        mkdir -p $OUT/zstd
        cp -r src/* $OUT/zstd/
    ]]
})
