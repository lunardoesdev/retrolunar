return recipe({
    version = "0.46.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/pixman.tar.gz ]; then
          curl -fSL -C - -o dl/pixman.tar.gz "https://www.cairographics.org/releases/pixman-0.46.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/pixman.tar.gz -C src --strip-components=1
        mkdir -p $OUT/pixman
        cp -r src/* $OUT/pixman/
    ]]
})