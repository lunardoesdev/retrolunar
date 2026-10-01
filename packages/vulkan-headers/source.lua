return recipe({
    version = "1.4.364",
    build = [[
        mkdir -p dl
        if [ ! -f dl/vulkan-headers.tar.gz ]; then
          curl -fSL -C - -o dl/vulkan-headers.tar.gz "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.4.364.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/vulkan-headers.tar.gz -C src --strip-components=1
        mkdir -p $OUT/vulkan-headers
        cp -r src/* $OUT/vulkan-headers/
    ]]
})
