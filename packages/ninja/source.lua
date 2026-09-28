return recipe({
    version = "1.13.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ninja.tar.gz ]; then
          curl -fSL -C - -o dl/ninja.tar.gz "https://github.com/ninja-build/ninja/archive/refs/tags/v1.13.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/ninja.tar.gz -C src --strip-components=1
        mkdir -p $OUT/ninja
        cp -r src/* $OUT/ninja/
    ]]
})
