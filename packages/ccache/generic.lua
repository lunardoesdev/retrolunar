require("ccache@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/ccache/* .
        # ccache is a compiler cache daemon: the deliverable is the `ccache`
        # program plus its man page, nothing else. Four switches:
        #   ENABLE_TESTING=OFF        ccache's unit tests run on the BUILD
        #                              host (CMakeLists.txt:136-137 adds
        #                              unittest/ and test/); forbidden here.
        #   ENABLE_DOCUMENTATION=OFF  builds the man pages, which needs
        #                              Sphinx on the host (line 116-118).
        #   REDIS_STORAGE_BACKEND=OFF and HTTP_STORAGE_BACKEND=OFF  both
        #                              default ON and pull bundled
        #                              third_party remote-storage code into
        #                              the daemon for no local benefit.
        # ENABLE_BENCHMARKS and ENABLE_IPO already default OFF.
        cmake -S . -B build $CMAKE_FLAGS \
            -DENABLE_TESTING=OFF \
            -DENABLE_DOCUMENTATION=OFF \
            -DREDIS_STORAGE_BACKEND=OFF \
            -DHTTP_STORAGE_BACKEND=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
