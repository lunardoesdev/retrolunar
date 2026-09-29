return recipe({
    version = "9.2.1143",
    git = "https://github.com/vim/vim",
    tag = "v9.2.1143",
    build = [[
        if [ ! -d src ]; then
          git clone --depth=1 --branch "$tag" "$git" src
        fi
        mkdir -p $OUT/vim
        cp -r src/. $OUT/vim/
    ]]
})
