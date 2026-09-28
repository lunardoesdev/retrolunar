return recipe({
    version = "3.4.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/eigen.tar.gz ]; then
          curl -fSL -C - -o dl/eigen.tar.gz "https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/eigen.tar.gz -C src --strip-components=1
        mkdir -p $OUT/eigen
        cp -r src/* $OUT/eigen/
    ]]
})
