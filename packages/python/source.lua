return recipe({
    version = "3.14.7",
    git = "https://github.com/python/cpython",
    tag = "v3.14.7",
    build = [[
        if [ ! -d src ]; then
          git clone --depth=1 --branch "$tag" "$git" src
        fi
        mkdir -p $OUT/python
        cp -r src/* $OUT/python/
    ]]
})
