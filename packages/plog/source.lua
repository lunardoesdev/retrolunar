return recipe({
    version = "1.1.11",
    build = [[
        mkdir -p dl
        if [ ! -f dl/plog.tar.gz ]; then
          curl -fSL -C - -o dl/plog.tar.gz "https://github.com/SergiusTheBest/plog/archive/refs/tags/1.1.11.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/plog.tar.gz -C src --strip-components=1
        mkdir -p $OUT/plog
        cp -r src/* $OUT/plog/
    ]]
})
