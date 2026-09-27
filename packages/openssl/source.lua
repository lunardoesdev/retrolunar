return recipe({
    version = "3.5.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/openssl.tar.gz ]; then
          curl -fSL -C - -o dl/openssl.tar.gz "https://www.openssl.org/source/openssl-3.5.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/openssl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/openssl
        cp -r src/* $OUT/openssl/
    ]]
})
