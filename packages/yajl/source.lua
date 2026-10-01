return recipe({
    version = "2.1.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/yajl.tar.gz ]; then
          curl -fSL -C - -o dl/yajl.tar.gz "https://github.com/lloyd/yajl/archive/refs/tags/2.1.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/yajl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/yajl
        cp -r src/* $OUT/yajl/
    ]]
})
