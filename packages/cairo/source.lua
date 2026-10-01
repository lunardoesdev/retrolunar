return recipe({
    version = "1.18.6",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cairo.tar.xz ]; then
          curl -fSL -C - -o dl/cairo.tar.xz "https://cairographics.org/releases/cairo-1.18.6.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/cairo.tar.xz -C src --strip-components=1
        mkdir -p $OUT/cairo
        cp -r src/* $OUT/cairo/
    ]]
})