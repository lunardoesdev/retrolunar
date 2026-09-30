return recipe({
    version = "1.34.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/c-ares.tar.gz ]; then
          curl -fSL -C - -o dl/c-ares.tar.gz "https://github.com/c-ares/c-ares/releases/download/v1.34.8/c-ares-1.34.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/c-ares.tar.gz -C src --strip-components=1
        mkdir -p $OUT/c-ares
        cp -r src/* $OUT/c-ares/
    ]]
})
