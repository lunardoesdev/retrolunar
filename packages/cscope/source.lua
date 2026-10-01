return recipe({
    version = "15.9",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cscope.tar.xz ]; then
          curl -fSL -C - -o dl/cscope.tar.xz "http://deb.debian.org/debian/pool/main/c/cscope/cscope_15.9.orig.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/cscope.tar.xz -C src --strip-components=1
        mkdir -p $OUT/cscope
        cp -r src/* $OUT/cscope/
    ]]
})