return recipe({
    version = "1.0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zopfli.tar.gz ]; then
          curl -fSL -C - -o dl/zopfli.tar.gz "https://github.com/google/zopfli/archive/refs/tags/zopfli-1.0.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zopfli.tar.gz -C src --strip-components=1
        mkdir -p $OUT/zopfli
        cp -r src/* $OUT/zopfli/
    ]]
})