return recipe({
    version = "5.8.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/xz.tar.xz ]; then
          curl -fSL -C - -o dl/xz.tar.xz "https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/xz.tar.xz -C src --strip-components=1
        mkdir -p $OUT/xz
        cp -r src/* $OUT/xz/
    ]]
})
