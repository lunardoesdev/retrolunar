return recipe({
    version = "1.4.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/highway.tar.gz ]; then
          curl -fSL -C - -o dl/highway.tar.gz "https://github.com/google/highway/archive/refs/tags/1.4.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/highway.tar.gz -C src --strip-components=1
        mkdir -p $OUT/highway
        cp -r src/* $OUT/highway/
    ]]
})
