return recipe({
    version = "2.6.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sfml.tar.gz ]; then
          curl -fSL -C - -o dl/sfml.tar.gz "https://github.com/SFML/SFML/archive/refs/tags/2.6.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/sfml.tar.gz -C src --strip-components=1
        mkdir -p $OUT/sfml
        cp -r src/* $OUT/sfml/
    ]]
})
