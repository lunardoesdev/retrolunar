# Boost superproject -- the one piece upstream does not ship.
#
# WHY THIS FILE EXISTS, precisely. Boost 1.92 ships a working cmake install
# mechanism, tools/cmake/include/BoostInstall.cmake (610 lines, with
# boost_install() at :559 and install(EXPORT ...) at :113). It ships no
# project that drives it. Only 19 of the 154 libraries that have a
# CMakeLists.txt ever call it, e.g. libs/mp11/CMakeLists.txt:55-57:
#     include(BoostInstall)
#     boost_install(TARGETS boost_mp11 HEADER_DIRECTORY include/)
# filesystem, atomic and program_options -- the three i2pd asks for at
# build/CMakeLists.txt:289 -- do not, so the functions load for nobody and
# `cmake --install` writes nothing. Confirmed: grep -c 'install(' over those
# three CMakeLists.txt is 0, and an early trial of this file without the
# boost_install() call installed zero files.
#
# The missing caller also needs a project(): add_subdirectory() requires it,
# and the release tarball has no top-level CMakeLists.txt. Upstream generates
# this file with BoostUp, which is not shipped either -- and libs/mp11
# works around that by FETCHING boostorg/cmake from GitHub at configure time
# (libs/mp11/CMakeLists.txt:31-32), which AGENTS.md forbids. Everything this
# file needs is already in the tarball.
#
# So this is NOT a second install implementation. Every archive, package
# config, version file and export set is produced by BoostInstall.cmake. What
# lives here is the project() call, the library list, the header-directory
# fix below, and the boost_install() invocation.
cmake_minimum_required(VERSION 3.16)
project(boost VERSION 1.92.0 LANGUAGES CXX)

# Every per-library CMakeLists.txt reads this (e.g.
# libs/filesystem/CMakeLists.txt:11 `project(BoostFilesystem VERSION
# "${BOOST_SUPERPROJECT_VERSION}")`). Unset, the sub-projects get an empty
# version.
set(BOOST_SUPERPROJECT_VERSION 1.92.0)

# BOOST_INCLUDE_LIBRARIES makes the per-library config checks use the unified
# include tree instead of per-library include paths that do not exist in the
# tarball. BOOST_ALL_NO_LIB turns off boost/config/auto_link.hpp, which is
# what the per-library CMakeLists.txt files themselves do
# (libs/filesystem/CMakeLists.txt:119-125).
set(BOOST_INCLUDE_LIBRARIES ON CACHE BOOL "" FORCE)
set(BOOST_ALL_NO_LIB ON)
# "system" layout, so headers land at include/boost/ rather than
# include/boost-1_92_0/. A consumer passing -I$PREFIX/include needs the
# former. This is the cmake spelling of the flag b2 took as --layout=system.
set(BOOST_INSTALL_LAYOUT "system" CACHE STRING "")

# The libraries are SHARED, and that is not a preference -- it is what the
# consumer requires. i2pd builds with WITH_STATIC=OFF, the project default,
# and build/CMakeLists.txt:277-287 then adds
#     -DBOOST_ATOMIC_DYN_LINK -DBOOST_FILESYSTEM_DYN_LINK
#     -DBOOST_PROGRAM_OPTIONS_DYN_LINK
# which on Windows turn every declaration into __declspec(dllimport). A static
# archive cannot satisfy that: linking i2pd against a static Boost fails on
# __imp_-prefixed symbols, measured as
#     undefined reference to
#     `__imp__ZNK5boost15program_options22abstract_variables_mapixERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE'
# So BUILD_SHARED_LIBS is ON. Setting it here rather than passing -D on the
# command line keeps the decision with the thing that knows why.
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)

# BoostInstall and its config helpers ship under tools/cmake in the tarball.
# CMAKE_MODULE_PATH is what makes include(BoostInstall) find them;
# include_directories() would not, it only affects the compiler.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/tools/cmake/include)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/tools/cmake/config)

# THE LIBRARY LIST, and why it is 38 entries long.
#
# Boost has no dependency declaration for the cmake build, so the list was
# closed by hand: configure, read every "The link interface of target X
# contains: Boost::Y but the target was not found", add Y, repeat, until no
# addable target remained. It converges after filesystem, program_options
# and these 35 header-only libraries:
set(_libs
    config assert container_hash detail io iterator smart_ptr system
    type_traits core predef scope winapi container atomic align any compat
    concept_check describe intrusive preprocessor throw_exception function
    fusion move mp11 type_index variant2 mpl bind function_types lexical_cast
    optional tuple utility tokenizer typeof
    filesystem program_options)

foreach(_l IN LISTS _libs)
    add_subdirectory(libs/${_l})
endforeach()

# THE UNIFIED-LAYOUT FIX.
#
# The release tarball has headers in boost/ only. libs/<lib>/include does not
# exist -- `ls libs/assert/include` fails, and the directory listing of
# libs/assert/ is CMakeLists.txt README.md build.jam doc extra index.html meta
# test. Yet every per-library CMakeLists.txt does
# target_include_directories(<t> PUBLIC include)
# (libs/filesystem/CMakeLists.txt:116, libs/config/CMakeLists.txt:14).
#
# That is not merely a missing include path; install(EXPORT) refuses it
# outright, because an INTERFACE_INCLUDE_DIRECTORIES pointing into the source
# tree cannot be written into an installed targets file:
#     Target "boost_filesystem" INTERFACE_INCLUDE_DIRECTORIES property
#     contains path: ".../libs/filesystem/include" which is prefixed in the
#     source directory.
#
# BoostInstall's __boost_install_update_include_directory
# (tools/cmake/include/BoostInstall.cmake:206-216) is what repairs this, but
# only when the property already matches $<BUILD_INTERFACE:${incdir}> exactly
# -- it then appends $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>. So the
# value is written in that form rather than as a bare path. Verified both
# ways: a bare path fails configure with the error above; the
# $<BUILD_INTERFACE:...> form configures clean.
foreach(_t boost_filesystem boost_program_options boost_atomic boost_container
             boost_config boost_assert boost_container_hash boost_detail boost_io
             boost_iterator boost_smart_ptr boost_system boost_type_traits boost_core
             boost_predef boost_scope boost_winapi boost_align boost_any boost_compat
             boost_concept_check boost_describe boost_intrusive boost_preprocessor
             boost_throw_exception boost_function boost_fusion boost_move boost_mp11
             boost_type_index boost_variant2 boost_mpl boost_bind boost_function_types
             boost_lexical_cast boost_optional boost_tuple boost_utility
             boost_tokenizer boost_typeof)
    if(TARGET ${_t})
        set_target_properties(${_t} PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES
                "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>")
    endif()
endforeach()

# WHY EVERY HEADER-ONLY LIBRARY IS PASSED TO boost_install() TOO.
#
# install(EXPORT) rejects a target whose INTERFACE_LINK_LIBRARIES names
# another target that is not itself in an export set:
#     install(EXPORT "boost_filesystem-targets" ...) includes target
#     "boost_filesystem" which requires target "boost_assert" that is not in
#     any export set.
# boost_filesystem links Boost::assert PUBLIC (libs/filesystem/CMakeLists.txt
# :228-244), so the header-only libraries have to be exported as well. They
# contribute no archive -- they are INTERFACE targets -- only their headers
# and their alias. list(REMOVE_DUPLICATES) matters because atomic, container,
# filesystem and program_options appear in both lists.
set(_exported)
foreach(_l IN LISTS _libs)
    if(TARGET boost_${_l})
        list(APPEND _exported boost_${_l})
    endif()
endforeach()
list(REMOVE_DUPLICATES _exported)

# HEADER_DIRECTORY is the SOURCE ROOT, not boost/.
# boost_install() does install(DIRECTORY "${__HEADER_DIRECTORY}/" DESTINATION
# include) (BoostInstall.cmake:581-584), which copies the directory's
# CONTENTS. Given boost/ that puts align.hpp at include/align.hpp and
# #include <boost/version.hpp> stops resolving. Given the source root it
# installs boost/ under include/, which is what consumers and
# -I$PREFIX/include expect. Measured: 18060 headers at include/boost/.
include(BoostInstall)
boost_install(VERSION 1.92.0
    HEADER_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    TARGETS ${_exported})