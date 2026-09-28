return recipe({
    version = "5.46",
    build = [[
        mkdir -p dl
        if [ ! -f dl/file.tar.gz ]; then
          curl -fSL -C - -o dl/file.tar.gz "https://astron.com/pub/file/file-5.46.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/file.tar.gz -C src --strip-components=1
        mkdir -p $OUT/file
        cp -r src/* $OUT/file/
    ]]
})
