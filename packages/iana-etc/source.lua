return recipe({
    version = "20260911",
    build = [[
        mkdir -p dl
        if [ ! -f dl/iana-etc.tar.gz ]; then
          curl -fSL -C - -o dl/iana-etc.tar.gz "https://github.com/Mic92/iana-etc/releases/download/20260911/iana-etc-20260911.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/iana-etc.tar.gz -C src --strip-components=1
        mkdir -p $OUT/iana-etc
        cp -r src/* $OUT/iana-etc/
    ]]
})
