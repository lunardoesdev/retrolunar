return recipe({
    version = "1.37.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/aria2.tar.gz ]; then
          curl -fSL -C - -o dl/aria2.tar.gz "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/aria2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/aria2
        cp -r src/* $OUT/aria2/
    ]]
})
