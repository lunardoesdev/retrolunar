return recipe({
    version = "3.11.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/nlohmann-json.tar.gz ]; then
          curl -fSL -C - -o dl/nlohmann-json.tar.gz "https://github.com/nlohmann/json/archive/refs/tags/v3.11.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/nlohmann-json.tar.gz -C src --strip-components=1
        mkdir -p $OUT/nlohmann-json
        cp -r src/* $OUT/nlohmann-json/
    ]]
})
