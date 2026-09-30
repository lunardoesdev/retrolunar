return recipe({
    version = "20260817.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/abseil-cpp.tar.gz ]; then
          curl -fSL -C - -o dl/abseil-cpp.tar.gz "https://github.com/abseil/abseil-cpp/archive/refs/tags/20260817.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/abseil-cpp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/abseil-cpp
        cp -r src/* $OUT/abseil-cpp/
    ]]
})
