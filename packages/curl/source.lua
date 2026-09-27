return recipe({
    version = "8.22.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/curl.tar.gz ]; then
          curl -fSL -C - -o dl/curl.tar.gz "https://curl.se/download/curl-8.22.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/curl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/curl
        cp -r src/* $OUT/curl/
    ]]
})
