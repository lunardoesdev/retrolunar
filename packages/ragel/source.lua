return recipe({
    version = "6.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ragel.tar.gz ]; then
          curl -fSL -C - -o dl/ragel.tar.gz "http://www.colm.net/files/ragel/ragel-6.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/ragel.tar.gz -C src --strip-components=1
        mkdir -p $OUT/ragel
        cp -r src/* $OUT/ragel/
    ]]
})
