return recipe({
    version = "1.22.0",
    git = "https://github.com/microsoft/onnxruntime",
    tag = "v1.22.0",
    build = [[
        if [ ! -d src ]; then
          git clone --depth=1 --recursive --branch "$tag" "$git" src
        fi
        mkdir -p $OUT/onnxruntime
        cp -r src/* $OUT/onnxruntime/
    ]]
})
