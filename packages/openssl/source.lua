return recipe({
    version = "4.0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/openssl.tar.gz ]; then
          curl -fSL -C - -o dl/openssl.tar.gz "https://github.com/openssl/openssl/releases/download/openssl-4.0.3/openssl-4.0.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/openssl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/openssl
        cp -r src/* $OUT/openssl/
    ]]
})
