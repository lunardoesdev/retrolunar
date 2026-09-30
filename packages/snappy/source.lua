return recipe({
    version = "1.2.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/snappy.tar.gz ]; then
          curl -fSL -C - -o dl/snappy.tar.gz "https://github.com/google/snappy/archive/refs/tags/1.2.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/snappy.tar.gz -C src --strip-components=1
        mkdir -p $OUT/snappy
        cp -r src/* $OUT/snappy/
    ]]
})
