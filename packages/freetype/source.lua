return recipe({
    version = "2.13.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/freetype.tar.gz ]; then
          curl -fSL -C - -o dl/freetype.tar.gz "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.gz" || curl -fSL -C - -o dl/freetype.tar.gz "https://github.com/freetype/freetype/archive/refs/tags/VER-2-13-3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/freetype.tar.gz -C src --strip-components=1
        mkdir -p $OUT/freetype
        cp -r src/* $OUT/freetype/
    ]]
})
