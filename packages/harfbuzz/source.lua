return recipe({
    version = "14.5.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/harfbuzz.tar.xz ]; then
          curl -fSL -C - -o dl/harfbuzz.tar.xz "https://github.com/harfbuzz/harfbuzz/releases/download/14.5.0/harfbuzz-14.5.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/harfbuzz.tar.xz -C src --strip-components=1
        mkdir -p $OUT/harfbuzz
        cp -r src/* $OUT/harfbuzz/
    ]]
})
