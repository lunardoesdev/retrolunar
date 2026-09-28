return recipe({
    version = "2.45",
    build = [[
        mkdir -p dl
        if [ ! -f dl/binutils.tar.xz ]; then
          curl -fSL -C - -o dl/binutils.tar.xz "https://sourceware.org/pub/binutils/releases/binutils-2.45.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/binutils.tar.xz -C src --strip-components=1
        mkdir -p $OUT/binutils
        cp -r src/* $OUT/binutils/
    ]]
})
