return recipe({
    version = "5.45.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/expect.tar.gz ]; then
          curl -fSL -C - -o dl/expect.tar.gz "https://prdownloads.sourceforge.net/expect/expect5.45.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/expect.tar.gz -C src --strip-components=1
        mkdir -p $OUT/expect
        cp -r src/* $OUT/expect/
    ]]
})
