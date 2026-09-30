return recipe({
    version = "4.4.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/toml11.tar.gz ]; then
          curl -fSL -C - -o dl/toml11.tar.gz "https://github.com/ToruNiina/toml11/archive/refs/tags/v4.4.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/toml11.tar.gz -C src --strip-components=1
        mkdir -p $OUT/toml11
        cp -r src/* $OUT/toml11/
    ]]
})
