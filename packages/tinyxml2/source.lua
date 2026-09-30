return recipe({
    version = "10.0.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tinyxml2.tar.gz ]; then
          curl -fSL -C - -o dl/tinyxml2.tar.gz "https://github.com/leethomason/tinyxml2/archive/refs/tags/10.0.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tinyxml2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tinyxml2
        cp -r src/* $OUT/tinyxml2/
    ]]
})
