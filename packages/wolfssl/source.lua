return recipe({
    version = "5.8.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/wolfssl.tar.gz ]; then
          curl -fSL -C - -o dl/wolfssl.tar.gz "https://github.com/wolfSSL/wolfssl/archive/refs/tags/v5.8.2-stable.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/wolfssl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/wolfssl
        cp -r src/* $OUT/wolfssl/
    ]]
})
