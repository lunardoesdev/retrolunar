return recipe({
    version = "685",
    build = [[
        mkdir -p dl
        if [ ! -f dl/less.tar.gz ]; then
          curl -fSL -C - -o dl/less.tar.gz "https://www.greenwoodsoftware.com/less/less-685.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/less.tar.gz -C src --strip-components=1
        mkdir -p $OUT/less
        cp -r src/* $OUT/less/
    ]]
})
