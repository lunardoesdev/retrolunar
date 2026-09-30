return recipe({
    version = "0.7.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/glog.tar.gz ]; then
          curl -fSL -C - -o dl/glog.tar.gz "https://github.com/google/glog/archive/refs/tags/v0.7.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/glog.tar.gz -C src --strip-components=1
        mkdir -p $OUT/glog
        cp -r src/* $OUT/glog/
    ]]
})
