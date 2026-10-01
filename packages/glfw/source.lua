-- GLFW publishes no binary release asset on any tag: the "Source code
-- (tar.gz)" link on a release page is GitHub's auto-generated tag archive,
-- and the URL below is that same archive in a stable, version-pinned form.
-- Verified HTTP 200; the archive's single top-level directory is
-- glfw-3.5.1, so the recipe strips one component. 3.5.1 is the newest tag.
return recipe({
    version = "3.5.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/glfw.tar.gz ]; then
          curl -fSL -C - -o dl/glfw.tar.gz "https://github.com/glfw/glfw/archive/refs/tags/3.5.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/glfw.tar.gz -C src --strip-components=1
        mkdir -p $OUT/glfw
        cp -r src/* $OUT/glfw/
    ]]
})