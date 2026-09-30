return recipe({
    version = "2.14",
    build = [[
        mkdir -p dl
        if [ ! -f dl/jansson.tar.gz ]; then
          curl -fSL -C - -o dl/jansson.tar.gz "https://github.com/akheron/jansson/releases/download/v2.14/jansson-2.14.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/jansson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/jansson
        cp -r src/* $OUT/jansson/
    ]]
})
