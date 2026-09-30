return recipe({
    version = "3.8.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/catch2.tar.gz ]; then
          curl -fSL -C - -o dl/catch2.tar.gz "https://github.com/catchorg/Catch2/archive/refs/tags/v3.8.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/catch2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/catch2
        cp -r src/* $OUT/catch2/
    ]]
})
