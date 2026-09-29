return recipe({
    version = "4.5.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libxcrypt.tar.xz ]; then
          curl -fSL -C - -o dl/libxcrypt.tar.xz "https://github.com/besser82/libxcrypt/releases/download/v4.5.2/libxcrypt-4.5.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/libxcrypt.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libxcrypt
        cp -r src/* $OUT/libxcrypt/
    ]]
})
