return recipe({
    version = "7.0.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/msgpack-c.tar.gz ]; then
          curl -fSL -C - -o dl/msgpack-c.tar.gz "https://github.com/msgpack/msgpack-c/archive/refs/tags/c-7.0.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/msgpack-c.tar.gz -C src --strip-components=1
        mkdir -p $OUT/msgpack-c
        cp -r src/* $OUT/msgpack-c/
    ]]
})
