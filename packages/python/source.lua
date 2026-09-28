return recipe({
    version = "3.14.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/python.tar.gz ]; then
          curl -fSL -C - -o dl/python.tar.gz "https://github.com/python/cpython/archive/refs/tags/v3.14.7.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/python.tar.gz -C src --strip-components=1
        mkdir -p $OUT/python
        cp -r src/* $OUT/python/
    ]]
})
