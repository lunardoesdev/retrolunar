return recipe({
    version = "1.5.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/draco.tar.gz ]; then
          curl -fSL -C - -o dl/draco.tar.gz "https://github.com/google/draco/archive/refs/tags/1.5.7.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/draco.tar.gz -C src --strip-components=1
        mkdir -p $OUT/draco
        cp -r src/* $OUT/draco/
    ]]
})
