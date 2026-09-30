return recipe({
    version = "1.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/meshoptimizer.tar.gz ]; then
          curl -fSL -C - -o dl/meshoptimizer.tar.gz "https://github.com/zeux/meshoptimizer/archive/refs/tags/v1.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/meshoptimizer.tar.gz -C src --strip-components=1
        mkdir -p $OUT/meshoptimizer
        cp -r src/* $OUT/meshoptimizer/
    ]]
})
