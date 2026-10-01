return recipe({
    version = "3.0.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lexbor.tar.gz ]; then
          curl -fSL -C - -o dl/lexbor.tar.gz "https://github.com/lexbor/lexbor/archive/refs/tags/v3.0.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lexbor.tar.gz -C src --strip-components=1
        mkdir -p $OUT/Lexbor
        cp -r src/* $OUT/Lexbor/
    ]]
})