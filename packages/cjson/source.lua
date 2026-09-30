return recipe({
    version = "1.7.19",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cjson.tar.gz ]; then
          curl -fSL -C - -o dl/cjson.tar.gz "https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.19.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/cjson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/cjson
        cp -r src/* $OUT/cjson/
    ]]
})
