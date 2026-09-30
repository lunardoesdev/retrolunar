return recipe({
    version = "1.1.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/brotli.tar.gz ]; then
          curl -fSL -C - -o dl/brotli.tar.gz "https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/brotli.tar.gz -C src --strip-components=1
        mkdir -p $OUT/brotli
        cp -r src/* $OUT/brotli/
    ]]
})
