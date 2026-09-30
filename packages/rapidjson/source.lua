return recipe({
    version = "1.1.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/rapidjson.tar.gz ]; then
          curl -fSL -C - -o dl/rapidjson.tar.gz "https://github.com/Tencent/rapidjson/archive/refs/tags/v1.1.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/rapidjson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/rapidjson
        cp -r src/* $OUT/rapidjson/
    ]]
})