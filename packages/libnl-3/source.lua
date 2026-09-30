return recipe({
    version = "3.12.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libnl.tar.gz ]; then
          curl -fSL -C - -o dl/libnl.tar.gz "https://github.com/thom311/libnl/releases/download/libnl3_12_0/libnl-3.12.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libnl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libnl-3
        cp -r src/* $OUT/libnl-3/
    ]]
})
