return recipe({
    version = "3.6.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/mbedtls.tar.bz2 ]; then
          curl -fSL -C - -o dl/mbedtls.tar.bz2 "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.3/mbedtls-3.6.3.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/mbedtls.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/mbedtls
        cp -r src/* $OUT/mbedtls/
    ]]
})
