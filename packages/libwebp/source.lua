return recipe({
    version = "1.4.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libwebp.tar.gz ]; then
          curl -fSL -C - -o dl/libwebp.tar.gz "https://github.com/webmproject/libwebp/archive/refs/tags/v1.4.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libwebp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libwebp
        cp -r src/* $OUT/libwebp/
    ]]
})
