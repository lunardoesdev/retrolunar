return recipe({
    version = "0.11.25",
    build = [[
        mkdir -p dl
        if [ ! -f dl/miniaudio.tar.gz ]; then
          curl -fSL -C - -o dl/miniaudio.tar.gz "https://github.com/mackron/miniaudio/archive/refs/tags/0.11.25.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/miniaudio.tar.gz -C src --strip-components=1
        mkdir -p $OUT/miniaudio
        cp -r src/* $OUT/miniaudio/
    ]]
})
