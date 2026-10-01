return recipe({
    version = "1.33.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/mpg123.tar.bz2 ]; then
          curl -fSL -C - -o dl/mpg123.tar.bz2 "https://www.mpg123.de/download/mpg123-1.33.7.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/mpg123.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/mpg123
        cp -r src/* $OUT/mpg123/
    ]]
})
