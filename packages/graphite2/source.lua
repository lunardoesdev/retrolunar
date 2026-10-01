return recipe({
    version = "1.3.15",
    build = [[
        mkdir -p dl
        if [ ! -f dl/graphite2.tar.gz ]; then
          curl -fSL -C - -o dl/graphite2.tar.gz "https://deb.debian.org/debian/pool/main/g/graphite2/graphite2_1.3.15.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/graphite2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/graphite2
        cp -r src/* $OUT/graphite2/
    ]]
})