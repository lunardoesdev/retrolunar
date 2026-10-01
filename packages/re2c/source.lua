return recipe({
    version = "4.6",
    build = [[
        mkdir -p dl
        if [ ! -f dl/re2c.tar.xz ]; then
          curl -fSL -C - -o dl/re2c.tar.xz "https://github.com/skvadrik/re2c/releases/download/4.6/re2c-4.6.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/re2c.tar.xz -C src --strip-components=1
        mkdir -p $OUT/re2c
        cp -r src/* $OUT/re2c/
    ]]
})
