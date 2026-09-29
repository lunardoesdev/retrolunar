return recipe({
    version = "4.4.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/make.tar.gz ]; then
          curl -fSL -C - -o dl/make.tar.gz "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/make.tar.gz -C src --strip-components=1
        mkdir -p $OUT/make
        cp -r src/* $OUT/make/
    ]]
})
