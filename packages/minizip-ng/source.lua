return recipe({
    version = "4.0.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/minizip-ng.tar.gz ]; then
          curl -fSL -C - -o dl/minizip-ng.tar.gz "https://github.com/zlib-ng/minizip-ng/archive/refs/tags/4.0.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/minizip-ng.tar.gz -C src --strip-components=1
        mkdir -p $OUT/minizip-ng
        cp -r src/* $OUT/minizip-ng/
    ]]
})
