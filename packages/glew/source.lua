-- GLEW publishes three archives per release; the .tgz is the source tree.
-- Verified HTTP 200 (866060 bytes, matching the server's Content-Length).
-- The archive's single top-level directory is glew-2.3.1, so the recipe
-- strips one component. 2.3.1 is the newest tag.
return recipe({
    version = "2.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/glew.tgz ]; then
          curl -fSL -C - -o dl/glew.tgz "https://github.com/nigels-com/glew/releases/download/glew-2.3.1/glew-2.3.1.tgz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/glew.tgz -C src --strip-components=1
        mkdir -p $OUT/glew
        cp -r src/* $OUT/glew/
    ]]
})