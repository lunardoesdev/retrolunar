return recipe({
    version = "1.18.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/doxygen.tar.gz ]; then
          curl -fSL -C - -o dl/doxygen.tar.gz "https://github.com/doxygen/doxygen/releases/download/Release_1_18_0/doxygen-1.18.0.src.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/doxygen.tar.gz -C src --strip-components=1
        mkdir -p $OUT/doxygen
        cp -r src/* $OUT/doxygen/
    ]]
})