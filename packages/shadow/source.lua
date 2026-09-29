return recipe({
    version = "4.20.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/shadow.tar.xz ]; then
          curl -fSL -C - -o dl/shadow.tar.xz "https://github.com/shadow-maint/shadow/releases/download/4.20.3/shadow-4.20.3.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/shadow.tar.xz -C src --strip-components=1
        mkdir -p $OUT/shadow
        cp -r src/* $OUT/shadow/
    ]]
})
