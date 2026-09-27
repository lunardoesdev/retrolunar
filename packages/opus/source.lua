return recipe({
    version = "1.5.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/opus.tar.gz ]; then
          curl -fSL -C - -o dl/opus.tar.gz "https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/opus.tar.gz -C src --strip-components=1
        mkdir -p $OUT/opus
        cp -r src/* $OUT/opus/
    ]]
})
