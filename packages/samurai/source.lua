return recipe({
    version = "1.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/samurai.tar.gz ]; then
          curl -fSL -C - -o dl/samurai.tar.gz "https://github.com/michaelforney/samurai/releases/download/1.3/samurai-1.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/samurai.tar.gz -C src --strip-components=1
        mkdir -p $OUT/samurai
        cp -r src/* $OUT/samurai/
    ]]
})
