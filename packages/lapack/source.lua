return recipe({
    version = "3.12.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lapack.tar.gz ]; then
          curl -fSL -C - -o dl/lapack.tar.gz "https://www.netlib.org/lapack/lapack-3.12.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lapack.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lapack
        cp -r src/* $OUT/lapack/
    ]]
})