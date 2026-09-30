return recipe({
    version = "1.51.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libuv.tar.gz ]; then
          curl -fSL -C - -o dl/libuv.tar.gz "https://github.com/libuv/libuv/archive/refs/tags/v1.51.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libuv.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libuv
        cp -r src/* $OUT/libuv/
    ]]
})
