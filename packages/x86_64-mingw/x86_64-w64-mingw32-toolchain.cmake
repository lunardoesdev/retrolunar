# mingw-w64 cross toolchain: no sysroot, plain binutils.
# CMAKE_FIND_ROOT_PATH covers PREFIX only; program lookup stays NEVER
# so host tools (ninja, pkg-config) are used, never prefixed ones.
set(CMAKE_SYSTEM_NAME Windows)

# CPU architecture
set(CMAKE_SYSTEM_PROCESSOR "x86_64")

# C compiler from the environment if not already set
if(NOT CMAKE_C_COMPILER)
  set(CMAKE_C_COMPILER "$ENV{CC}" CACHE FILEPATH "C compiler" FORCE)
endif()
# Same for C++
if(NOT CMAKE_CXX_COMPILER)
  set(CMAKE_CXX_COMPILER "$ENV{CXX}" CACHE FILEPATH "C++ compiler" FORCE)
endif()

# Resource compiler for .rc files (windres ships with mingw-w64)
set(CMAKE_RC_COMPILER "x86_64-w64-mingw32-windres" CACHE FILEPATH "resource compiler" FORCE)

set(CMAKE_AR "$ENV{AR}" CACHE FILEPATH "archiver" FORCE)
set(CMAKE_RANLIB "$ENV{RANLIB}" CACHE FILEPATH "ranlib" FORCE)
set(CMAKE_STRIP "$ENV{STRIP}" CACHE FILEPATH "strip" FORCE)
set(CMAKE_READELF "$ENV{READELF}" CACHE FILEPATH "readelf" FORCE)
set(CMAKE_OBJDUMP "$ENV{OBJDUMP}" CACHE FILEPATH "objdump" FORCE)
set(CMAKE_OBJCOPY "$ENV{OBJCOPY}" CACHE FILEPATH "objcopy" FORCE)
set(CMAKE_NM "$ENV{NM}" CACHE FILEPATH "nm" FORCE)
set(CMAKE_ASM_COMPILER "$ENV{AS}" CACHE FILEPATH "assembler" FORCE)
set(CMAKE_LINKER "$ENV{LD}" CACHE FILEPATH "linker" FORCE)
set(CMAKE_INSTALL_PREFIX "$ENV{PREFIX}" CACHE PATH "install prefix")

# For find_library/find_path look in PREFIX only (no sysroot here)
set(CMAKE_FIND_ROOT_PATH "$ENV{PREFIX}")

# Never look for runnable utilities in PREFIX (would find target .exe)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Libraries only in PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Headers only in PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# CMake packages also only in PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
