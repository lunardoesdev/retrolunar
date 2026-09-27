return recipe({
    version = "3.0.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libjpeg-turbo.tar.gz ]; then
          curl -fSL -C - -o dl/libjpeg-turbo.tar.gz "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libjpeg-turbo.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libjpeg-turbo
        cp -r src/* $OUT/libjpeg-turbo/
    ]]
})
