return recipe({
    version = "0.19",
    build = [[
        mkdir -p dl
        if [ ! -f dl/json-c.tar.gz ]; then
          curl -fSL -C - -o dl/json-c.tar.gz "https://github.com/json-c/json-c/archive/refs/tags/json-c-0.19-20260627.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/json-c.tar.gz -C src --strip-components=1
        mkdir -p $OUT/json-c
        cp -r src/* $OUT/json-c/
    ]]
})
