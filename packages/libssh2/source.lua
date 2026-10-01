return recipe({
    version = "1.11.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libssh2.tar.gz ]; then
          curl -fSL -C - -o dl/libssh2.tar.gz "https://github.com/libssh2/libssh2/releases/download/libssh2-1.11.1/libssh2-1.11.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libssh2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libssh2
        cp -r src/* $OUT/libssh2/
    ]]
})