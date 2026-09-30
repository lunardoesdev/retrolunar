return recipe({
    version = "11.1.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/fmt.tar.gz ]; then
          curl -fSL -C - -o dl/fmt.tar.gz "https://github.com/fmtlib/fmt/archive/refs/tags/11.1.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/fmt.tar.gz -C src --strip-components=1
        mkdir -p $OUT/fmt
        cp -r src/* $OUT/fmt/
    ]]
})
