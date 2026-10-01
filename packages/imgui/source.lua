-- Dear ImGui has no release assets and no build system in its tree; it is a
-- rolling trunk released as plain git tags. v1.92.9 is the newest non-docking
-- tag (the tree carries parallel -docking tags, which are a different branch
-- of development). Verified HTTP 200; the archive's single top-level
-- directory is imgui-1.92.9, so the recipe strips one component.
return recipe({
    version = "1.92.9",
    build = [[
        mkdir -p dl
        if [ ! -f dl/imgui.tar.gz ]; then
          curl -fSL -C - -o dl/imgui.tar.gz "https://github.com/ocornut/imgui/archive/refs/tags/v1.92.9.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/imgui.tar.gz -C src --strip-components=1
        mkdir -p $OUT/imgui
        cp -r src/* $OUT/imgui/
    ]]
})