return recipe({
    version = "2.10.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/kbd.tar.xz ]; then
          curl -fSL -C - -o dl/kbd.tar.xz "https://mirrors.edge.kernel.org/pub/linux/utils/kbd/kbd-2.10.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/kbd.tar.xz -C src --strip-components=1
        mkdir -p $OUT/kbd
        cp -r src/* $OUT/kbd/
    ]]
})
