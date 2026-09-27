return recipe({
    version = "1.6.48",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libpng.tar.gz ]; then
          curl -fSL -C - -o dl/libpng.tar.gz "https://download.sourceforge.net/libpng/libpng-1.6.48.tar.gz" || curl -fSL -C - -o dl/libpng.tar.gz "https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.48.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libpng.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libpng
        cp -r src/* $OUT/libpng/
    ]]
})
