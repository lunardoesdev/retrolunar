return recipe({
    version = "3.2.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tinyexr.tar.gz ]; then
          curl -fSL -C - -o dl/tinyexr.tar.gz "https://github.com/syoyo/tinyexr/archive/refs/tags/v3.2.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tinyexr.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tinyexr
        cp -r src/* $OUT/tinyexr/
    ]]
})
