return recipe({
    version = "3.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/distcc.tar.gz ]; then
          curl -fSL -C - -o dl/distcc.tar.gz "https://github.com/distcc/distcc/releases/download/v3.4/distcc-3.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/distcc.tar.gz -C src --strip-components=1
        mkdir -p $OUT/distcc
        cp -r src/* $OUT/distcc/
    ]]
})
