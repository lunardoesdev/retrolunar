return recipe({
    version = "1.0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/glm.tar.gz ]; then
          curl -fSL -C - -o dl/glm.tar.gz "https://github.com/g-truc/glm/archive/refs/tags/1.0.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/glm.tar.gz -C src --strip-components=1
        mkdir -p $OUT/glm
        cp -r src/* $OUT/glm/
    ]]
})
