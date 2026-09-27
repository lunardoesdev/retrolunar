return recipe({
    version = "5.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/raylib.tar.gz ]; then
          curl -fSL -C - -o dl/raylib.tar.gz "https://github.com/raysan5/raylib/archive/refs/tags/5.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/raylib.tar.gz -C src --strip-components=1
        mkdir -p $OUT/raylib
        cp -r src/* $OUT/raylib/
    ]]
})
