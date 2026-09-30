return recipe({
    version = "0.8.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/yaml-cpp.tar.gz ]; then
          curl -fSL -C - -o dl/yaml-cpp.tar.gz "https://github.com/jbeder/yaml-cpp/archive/refs/tags/0.8.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/yaml-cpp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/yaml-cpp
        cp -r src/* $OUT/yaml-cpp/
    ]]
})
