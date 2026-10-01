return recipe({
    version = "2.78",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libcap-2.78.tar.xz ]; then
          curl -fSL -C - -o dl/libcap-2.78.tar.xz "https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.78.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/libcap-2.78.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libcap
        cp -r src/* $OUT/libcap/
    ]]
})