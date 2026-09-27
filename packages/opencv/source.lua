return recipe({
    version = "4.10.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/opencv.tar.gz ]; then
          curl -fSL -C - -o dl/opencv.tar.gz "https://github.com/opencv/opencv/archive/refs/tags/4.10.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/opencv.tar.gz -C src --strip-components=1
        mkdir -p $OUT/opencv
        cp -r src/* $OUT/opencv/
    ]]
})
