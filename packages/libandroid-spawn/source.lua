return recipe({
    version = "0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/posix_spawn.cpp ]; then
          curl -fSL -C - -o dl/posix_spawn.cpp "https://raw.githubusercontent.com/termux/termux-packages/df1d0819efe79503cf5975012b751ab5132eb8c1/packages/libandroid-spawn/posix_spawn.cpp"
        fi
        if [ ! -f dl/posix_spawn.h ]; then
          curl -fSL -C - -o dl/posix_spawn.h "https://raw.githubusercontent.com/termux/termux-packages/df1d0819efe79503cf5975012b751ab5132eb8c1/packages/libandroid-spawn/posix_spawn.h"
        fi
        if [ ! -f dl/LICENSE ]; then
          curl -fSL -C - -o dl/LICENSE "https://raw.githubusercontent.com/termux/termux-packages/df1d0819efe79503cf5975012b751ab5132eb8c1/packages/libandroid-spawn/LICENSE"
        fi
        rm -rf src
        mkdir -p src
        cp dl/posix_spawn.cpp dl/posix_spawn.h dl/LICENSE src/
        mkdir -p $OUT/libandroid-spawn
        cp -r src/* $OUT/libandroid-spawn/
    ]]
})
