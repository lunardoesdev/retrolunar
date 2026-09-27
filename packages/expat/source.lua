return recipe({
    version = "2.7.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/expat.tar.gz ]; then
          curl -fSL -C - -o dl/expat.tar.gz "https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/expat.tar.gz -C src --strip-components=1
        mkdir -p $OUT/expat
        cp -r src/* $OUT/expat/
    ]]
})
