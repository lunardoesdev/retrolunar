return recipe({
    version = "2024.10.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/onnx.tar.gz ]; then
          curl -fSL -C - -o dl/onnx.tar.gz "https://github.com/onnx/onnx/archive/refs/tags/v1.18.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/onnx.tar.gz -C src --strip-components=1
        mkdir -p $OUT/onnx
        cp -r src/* $OUT/onnx/
    ]]
})
