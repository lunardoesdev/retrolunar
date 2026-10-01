require("vulkan-headers@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/vulkan-headers/* .
        # Header-only registry: the Vulkan-Headers target is an INTERFACE
        # library (CMakeLists.txt:52), so nothing is compiled and the install
        # is a file copy that is identical on every system. cmake runs only to
        # drive upstream's own install rules, which is what gets the layout
        # right - see the three install(DIRECTORY ...) lines below.
        #
        # VULKAN_HEADERS_ENABLE_TESTS=OFF is the only switch that matters.
        # CMakeLists.txt:45 defaults it to ${PROJECT_IS_TOP_LEVEL}, which is
        # ON here, and :79-82 then does add_subdirectory(tests). That
        # directory's CMakeLists.txt is nothing but three add_test() calls
        # (tests/CMakeLists.txt:10,20,25), each of which shells out to ctest
        # --build-and-test or cmake --install and then RUNS the freshly built
        # binary. On a cross build that is running a target binary, which this
        # repository forbids outright.
        #
        # VULKAN_HEADERS_ENABLE_INSTALL=ON (CMakeLists.txt:46, also defaulting
        # to PROJECT_IS_TOP_LEVEL) is the whole point of the run; the install
        # block at :84-125 is where all four artifacts come from. Passed
        # explicitly so the intent is visible.
        #
        # VULKAN_HEADERS_ENABLE_MODULE=OFF (CMakeLists.txt:47) turns off the
        # C++23 named-module target. cmake_dependent_option makes its default
        # depend on whether 23 is in CMAKE_CXX_COMPILER_IMPORT_STD, which
        # varies by host cmake/compiler combination - a default we must not
        # inherit. With it ON, :56-77 builds an OBJECT library from
        # vulkan.cppm/vulkan_video.cppm, which is real compilation of the
        # target's C++23 module machinery for no benefit to a header consumer.
        #
        # Installed, exactly as upstream lays it out:
        #   include/vulkan/         CMakeLists.txt:97  (vulkan.h, vulkan_core.h,
        #                            vulkan.hpp, the platform headers, and the
        #                            two .cppm files - the PATTERN EXCLUDE only
        #                            strips the .cppm when MODULE is ON)
        #   include/vk_video/       CMakeLists.txt:96  (the video codec headers)
        #   share/vulkan/registry/  CMakeLists.txt:99  (vk.xml and the
        #                            generator scripts, the "registry" half of
        #                            the package; NOT under include/)
        #   share/cmake/VulkanHeaders/  :112-124 (export set + version file)
        # There is no .pc file: upstream ships none.
        #
        # Note there is NO generated version header. CMakeLists.txt:17-40
        # (vlk_get_header_version) *reads* VK_HEADER_VERSION out of the shipped
        # include/vulkan/vulkan_core.h (:64, 364) to version the project; it
        # never writes a header back. The tree is copied verbatim.
        cmake -S . -B build $CMAKE_FLAGS -DVULKAN_HEADERS_ENABLE_TESTS=OFF -DVULKAN_HEADERS_ENABLE_INSTALL=ON -DVULKAN_HEADERS_ENABLE_MODULE=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
