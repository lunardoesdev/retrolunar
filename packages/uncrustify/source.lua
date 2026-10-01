return recipe({
    version = "0.83.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/uncrustify.tar.gz ]; then
          curl -fSL -C - -o dl/uncrustify.tar.gz "https://github.com/uncrustify/uncrustify/releases/download/uncrustify-0.83.0/uncrustify-0.83.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/uncrustify.tar.gz -C src --strip-components=1
        mkdir -p $OUT/uncrustify
        cp -r src/* $OUT/uncrustify/
    ]]
})