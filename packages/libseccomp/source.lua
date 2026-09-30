return recipe({
    version = "2.6.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libseccomp.tar.gz ]; then
          curl -fSL -C - -o dl/libseccomp.tar.gz "https://github.com/seccomp/libseccomp/releases/download/v2.6.1/libseccomp-2.6.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libseccomp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libseccomp
        cp -r src/* $OUT/libseccomp/
    ]]
})
