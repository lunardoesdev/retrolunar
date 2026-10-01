return recipe({
    version = "3.1.6",
    build = [[
        mkdir -p dl
        if [ ! -f dl/bear.tar.gz ]; then
          curl -fSL -C - -o dl/bear.tar.gz "http://deb.debian.org/debian/pool/main/b/bear/bear_3.1.6.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/bear.tar.gz -C src --strip-components=1
        mkdir -p $OUT/bear
        cp -r src/* $OUT/bear/
    ]]
})