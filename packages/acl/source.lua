return recipe({
    version = "2.3.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/acl.tar.xz ]; then
          curl -fSL -C - -o dl/acl.tar.xz "https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/acl.tar.xz -C src --strip-components=1
        mkdir -p $OUT/acl
        cp -r src/* $OUT/acl/
    ]]
})
