return recipe({
    version = "1.04",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lzop.tar.gz ]; then
          curl -fSL -C - -o dl/lzop.tar.gz "https://www.lzop.org/download/lzop-1.04.tar.gz" || \
          curl -fSL -C - -o dl/lzop.tar.gz "https://distfiles.macports.org/lzop/lzop-1.04.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lzop.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lzop
        cp -r src/* $OUT/lzop/
    ]]
})
