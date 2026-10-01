return recipe({
    version = "2.42.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/mold.tar.gz ]; then
          curl -fSL -C - -o dl/mold.tar.gz "https://github.com/rui314/mold/archive/refs/tags/v2.42.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/mold.tar.gz -C src --strip-components=1
        mkdir -p $OUT/mold
        cp -r src/* $OUT/mold/
    ]]
})