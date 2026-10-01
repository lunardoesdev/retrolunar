return recipe({
    version = "0.3.34",
    build = [[
        mkdir -p dl
        if [ ! -f dl/openblas.tar.gz ]; then
          curl -fSL -C - -o dl/openblas.tar.gz "https://github.com/OpenMathLib/OpenBLAS/releases/download/v0.3.34/OpenBLAS-0.3.34.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/openblas.tar.gz -C src --strip-components=1
        mkdir -p $OUT/openblas
        cp -r src/* $OUT/openblas/
    ]]
})