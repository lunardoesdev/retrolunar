return recipe({
    version = "2.6.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/flex.tar.gz ]; then
          curl -fSL -C - -o dl/flex.tar.gz "https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/flex.tar.gz -C src --strip-components=1
        mkdir -p $OUT/flex
        cp -r src/* $OUT/flex/
    ]]
})
