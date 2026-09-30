return recipe({
    version = "1.0.16",
    build = [[
        mkdir -p dl
        if [ ! -f dl/fribidi.tar.xz ]; then
          curl -fSL -C - -o dl/fribidi.tar.xz "https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/fribidi.tar.xz -C src --strip-components=1
        mkdir -p $OUT/fribidi
        cp -r src/* $OUT/fribidi/
    ]]
})
