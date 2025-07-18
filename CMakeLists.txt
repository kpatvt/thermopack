# CMake build system for ThermoPack
# 
# To run (from the directory in which this file is found)
#   mkdir build
#   cd build
#   cmake ..
#   make install
#
# Installs files ("." refers to the directory in which this file is found)
#   ./installed/libthermopack.{dynamic library}
#   ./installed/libthermopack.{static library}
#   ./addon/pycThermopack/thermopack/libthermopack.{dynamic library}
#   ./installed/run_thermopack
#
#   (optional) ./installed/unittests
#
# Accepts options
#   test : Build unittests suite
#       cmake -Dtest=ON .. # CMakeCache.txt must be cleared to switch ON/OFF
#       make install
#       ../installed/unittests
#

cmake_minimum_required(VERSION 3.19)
project(ThermoPack LANGUAGES Fortran)

string(ASCII 27 Esc)
set(ColorRed "${Esc}[31m")
set(ColorYellow "${Esc}[93m")
set(ColorBlue "${Esc}[34m")
set(ColorDefault "${Esc}[0m")

if(NOT MSVC)
    execute_process(COMMAND bash -c "arch" OUTPUT_VARIABLE PROC)
    set(tp_flags_common "-cpp -fPIC -fdefault-real-8 -fdefault-double-8 -frecursive -fopenmp -Wno-unused-function -Wno-unused-variable")

    include(CheckCompilerFlag)
    check_compiler_flag(Fortran "-arch arm64" arm64_supported)
    if(arm64_supported)
        set(gf_proc "-arch arm64")
        set(gf_march "-arch arm64 -fno-expensive-optimizations")
    else()
        set(gf_proc "-mieee-fp")
        set(gf_march "-march=x86-64 -msse2")
    endif()

    set(tp_debug_flags "${gf_proc} ${tp_flags_common} -g -fbounds-check -fbacktrace -ffpe-trap=invalid,zero,overflow -Wno-unused-dummy-argument -Wall")
    set(tp_profile_flags "${tp_flags_common} -g -pg")
    set(tp_optim_flags "${tp_flags_common} -O3 ${gf_march} -funroll-loops")

    if(APPLE)
        set(CMAKE_FORTRAN_COMPILER /opt/homebrew/bin/gfortran)
        set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "The OSX architecture")
    endif()

    if (${CMAKE_Fortran_COMPILER_ID} STREQUAL "GNU")
        if (${CMAKE_Fortran_COMPILER_VERSION} VERSION_GREATER_EQUAL 15)
            message(STATUS "${ColorRed}There are KNOWN BUGS in gfortran 15 that break ThermoPack. You probably want to use a different compiler version.${ColorDefault}")
        endif()
    endif()
else()
    # Build using: cmake --build . --config Release
    set(tp_flags_common "/nologo /fpp /fpe:0 /names:lowercase /assume:underscore /fp:precise /extend-source:132 /iface:cref /Qdiag-disable:10448")
    set(tp_optim_flags "${tp_flags_common}")
    set(tp_debug_flags "${tp_flags_common} /check:bounds /traceback")
endif()

# Check if the build type is not set and set it to Release
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
endif()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    message(STATUS "Setting CMAKE_INSTALL_PREFIX: ${CMAKE_CURRENT_SOURCE_DIR}/installed")
    set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE ${CMAKE_CURRENT_SOURCE_DIR}/installed)
endif()

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/src "thermopack")

option(test "Build test suite" OFF)
if(test)
    cmake_policy(SET CMP0074 NEW)
    find_package(PFUNIT QUIET)
    if (NOT PFUNIT_FOUND)
        message("${ColorRed}Did not find pFUnit. If you have installed pFUnit, make sure that PFUNIT_DIR is set. Falling back to building pFUnit from source...${ColorDefault}")
        add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/external/pFUnit)
    else()
        message(STATUS "Found pFUnit: ${PFUNIT_DIR}")
    endif()
    message(STATUS "Creating run_unittests target")
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/unittests)
endif()
