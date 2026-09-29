return recipe({
    version = "2.14",
    build = [[
        mkdir -p dl
        if [ ! -f dl/grub.tar.xz ]; then
          curl -fSL -C - -o dl/grub.tar.xz "https://ftp.gnu.org/gnu/grub/grub-2.14.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/grub.tar.xz -C src --strip-components=1
        mkdir -p $OUT/grub
        cp -r src/* $OUT/grub/
    ]]
})
