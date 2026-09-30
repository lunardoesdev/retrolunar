return recipe({
    version = "1.8.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libconfig.tar.gz ]; then
          curl -fSL -C - -o dl/libconfig.tar.gz "https://github.com/hyperrealm/libconfig/archive/refs/tags/v1.8.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libconfig.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libconfig
        cp -r src/* $OUT/libconfig/
    ]]
})