return recipe({
    version = "0.7.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lrzip.tar.xz ]; then
          curl -fSL -C - -o dl/lrzip.tar.xz "https://github.com/ckolivas/lrzip/releases/download/v0.7.3/lrzip-0.7.3.tar.xz" || \
          curl -fSL -C - -o dl/lrzip.tar.xz "https://distfiles.macports.org/lrzip/lrzip-0.7.3.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/lrzip.tar.xz -C src --strip-components=1
        mkdir -p $OUT/lrzip
        cp -r src/* $OUT/lrzip/
    ]]
})
