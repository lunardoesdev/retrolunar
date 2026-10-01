return recipe({
    version = "2.0.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cmph.tar.gz ]; then
          curl -fSL -C - -o dl/cmph.tar.gz "http://deb.debian.org/debian/pool/main/c/cmph/cmph_2.0.2.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/cmph.tar.gz -C src --strip-components=1
        mkdir -p $OUT/cmph
        cp -r src/* $OUT/cmph/
    ]]
})