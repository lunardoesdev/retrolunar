return recipe({
    version = "3.8.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libarchive.tar.xz ]; then
          curl -fSL -C - -o dl/libarchive.tar.xz "https://github.com/libarchive/libarchive/releases/download/v3.8.1/libarchive-3.8.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/libarchive.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libarchive
        cp -r src/* $OUT/libarchive/
    ]]
})
