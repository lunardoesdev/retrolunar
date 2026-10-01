return recipe({
    version = "1.5.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/capnproto-c++-1.5.0.tar.gz ]; then
          curl -fSL -C - -o dl/capnproto-c++-1.5.0.tar.gz "https://capnproto.org/capnproto-c++-1.5.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/capnproto-c++-1.5.0.tar.gz -C src --strip-components=1
        mkdir -p $OUT/capnproto
        cp -r src/* $OUT/capnproto/
    ]]
})