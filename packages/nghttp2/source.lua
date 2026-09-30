return recipe({
    version = "1.68.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/nghttp2.tar.xz ]; then
          curl -fSL -C - -o dl/nghttp2.tar.xz "https://github.com/nghttp2/nghttp2/releases/download/v1.68.0/nghttp2-1.68.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/nghttp2.tar.xz -C src --strip-components=1
        mkdir -p $OUT/nghttp2
        cp -r src/* $OUT/nghttp2/
    ]]
})
