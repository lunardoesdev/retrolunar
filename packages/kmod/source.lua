return recipe({
    version = "34",
    git = "https://github.com/kmod-project/kmod",
    tag = "v34",
    build = [[
        if [ ! -d src ]; then
          git clone --depth=1 --branch "$tag" "$git" src
        fi
        mkdir -p $OUT/kmod
        cp -r src/. $OUT/kmod/
    ]]
})
