return recipe({
    version = "1.17.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/googletest.tar.gz ]; then
          curl -fSL -C - -o dl/googletest.tar.gz "https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/googletest.tar.gz -C src --strip-components=1
        mkdir -p $OUT/googletest
        cp -r src/* $OUT/googletest/
    ]]
})
