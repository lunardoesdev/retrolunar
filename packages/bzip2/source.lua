return recipe({
    version = "1.0.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/bzip2.tar.gz ]; then
          curl -fSL -C - -o dl/bzip2.tar.gz "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/bzip2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/bzip2
        cp -r src/* $OUT/bzip2/
    ]]
})
