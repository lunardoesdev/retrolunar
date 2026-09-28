return recipe({
    version = "b8901",
    build = [[
        mkdir -p dl
        if [ ! -f dl/llama.tar.gz ]; then
          curl -fSL -C - -o dl/llama.tar.gz "https://github.com/ggerganov/llama.cpp/archive/refs/tags/b8901.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/llama.tar.gz -C src --strip-components=1
        mkdir -p $OUT/llama
        cp -r src/* $OUT/llama/
    ]]
})
