-- GLAD2 is a generator, not a library: this repository ships Python and the
-- Khronos XML registries, and every C file a consumer compiles is produced at
-- build time. The v2.0.8 release has an EMPTY asset list - there is no
-- pre-generated tarball or zip attached to it - so there is nothing to
-- download but the generator. See generic.lua for how the sources are
-- produced. Verified HTTP 200; the archive's single top-level directory is
-- glad-2.0.8, so the recipe strips one component. v2.0.8 is the newest tag.
return recipe({
    version = "2.0.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/glad.tar.gz ]; then
          curl -fSL -C - -o dl/glad.tar.gz "https://github.com/Dav1dde/glad/archive/refs/tags/v2.0.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/glad.tar.gz -C src --strip-components=1
        mkdir -p $OUT/glad
        cp -r src/* $OUT/glad/
    ]]
})