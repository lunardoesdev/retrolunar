return recipe({
    version = "3.4.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tomlplusplus.tar.gz ]; then
          curl -fSL -C - -o dl/tomlplusplus.tar.gz "https://github.com/marzer/tomlplusplus/archive/refs/tags/v3.4.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tomlplusplus.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tomlplusplus
        cp -r src/* $OUT/tomlplusplus/
    ]]
})
