return recipe({
    version = "1.15.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/spdlog.tar.gz ]; then
          curl -fSL -C - -o dl/spdlog.tar.gz "https://github.com/gabime/spdlog/archive/refs/tags/v1.15.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/spdlog.tar.gz -C src --strip-components=1
        mkdir -p $OUT/spdlog
        cp -r src/* $OUT/spdlog/
    ]]
})
