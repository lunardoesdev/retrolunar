return recipe({
    version = "3500400",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sqlite.tar.gz ]; then
          curl -fSL -C - -o dl/sqlite.tar.gz "https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/sqlite.tar.gz -C src --strip-components=1
        mkdir -p $OUT/sqlite
        cp -r src/* $OUT/sqlite/
    ]]
})
