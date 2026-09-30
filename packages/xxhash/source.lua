return recipe({
    version = "0.8.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/xxhash.tar.gz ]; then
          curl -fSL -C - -o dl/xxhash.tar.gz "https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/xxhash.tar.gz -C src --strip-components=1
        mkdir -p $OUT/xxhash
        cp -r src/* $OUT/xxhash/
    ]]
})
