return recipe({
    version = "0.14.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libcbor.tar.gz ]; then
          curl -fSL -C - -o dl/libcbor.tar.gz "https://github.com/PJK/libcbor/archive/refs/tags/v0.14.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libcbor.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libcbor
        cp -r src/* $OUT/libcbor/
    ]]
})