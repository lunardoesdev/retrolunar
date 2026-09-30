return recipe({
    version = "3.12.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/simdjson.tar.gz ]; then
          curl -fSL -C - -o dl/simdjson.tar.gz "https://github.com/simdjson/simdjson/archive/refs/tags/v3.12.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/simdjson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/simdjson
        cp -r src/* $OUT/simdjson/
    ]]
})
