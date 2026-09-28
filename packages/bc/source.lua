return recipe({
    version = "7.0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/bc.tar.xz ]; then
          curl -fSL -C - -o dl/bc.tar.xz "https://github.com/gavinhoward/bc/releases/download/7.0.3/bc-7.0.3.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/bc.tar.xz -C src --strip-components=1
        mkdir -p $OUT/bc
        cp -r src/* $OUT/bc/
    ]]
})
