return recipe({
    version = "2.32.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sdl2.tar.gz ]; then
          curl -fSL -C - -o dl/sdl2.tar.gz "https://www.libsdl.org/release/SDL2-2.32.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/sdl2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/sdl2
        cp -r src/* $OUT/sdl2/
    ]]
})
