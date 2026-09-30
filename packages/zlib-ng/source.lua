return recipe({
    version = "2.2.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zlib-ng.tar.gz ]; then
          curl -fSL -C - -o dl/zlib-ng.tar.gz "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.2.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zlib-ng.tar.gz -C src --strip-components=1
        mkdir -p $OUT/zlib-ng
        cp -r src/* $OUT/zlib-ng/
    ]]
})
