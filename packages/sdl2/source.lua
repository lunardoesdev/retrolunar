return recipe({
    version = "2.32.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sdl2.tar.gz ]; then
          curl -fSL -C - -o dl/sdl2.tar.gz "https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/sdl2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/sdl2
        cp -r src/* $OUT/sdl2/
    ]]
})
