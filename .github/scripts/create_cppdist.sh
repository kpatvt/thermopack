#!/bin/bash
set -e

platforms=("macOS-latest" "macOS-12" "ubuntu-latest" "windows-latest")
dylib_dirs=(".dylibs" ".dylibs" "../thermopack.libs" "NO_DYLIB_DIR")

length=${#platforms[@]}
for ((i=0; i<$length; i++)); do
    platform=${platforms[$i]}
    whldir="wheel-v3-${platform}"
    dylib_dir=${dylib_dirs[$i]}
    if [ -d "$whldir" ]; then
        echo "--- Processing directory: $whldir ---"
        echo "Directory contains: "
        ls -AR $whldir

        # Create dist directory and move config- and header files to expected locations
        distdir="thermopack-${platform}"
        if [ "${platform}" == "ubuntu-latest" ]; then
            mkdir -p ${distdir}/installed/${dylib_dir}
        else
            mkdir -p ${distdir}/installed
        fi
        mkdir -p ${distdir}/addon/cppThermopack
        cp thermopack-config.cmake ${distdir}
        cp -r addon/cppThermopack/cppThermopack ${distdir}/addon/cppThermopack

        echo "--- Set up dist directory ${distdir} ---"
        ls -AR $distdir
        
        echo "--- Unpacking wheel ..." 
        cd $whldir
        unzip thermopack*
        cd ..
        mv ${whldir}/thermopack/libthermopack* ${distdir}/installed

        # Copy dynamic dependencies to expected location (relative to thermopack.so)
        if [ "${platform}" == "ubuntu-latest" ]; then
            mv ${whldir}/thermopack/${dylib_dir}/* ${distdir}/installed/${dylib_dir}
        fi

        echo "--- Completed move to dist directory ${distdir} ---"
        ls -AR ${distdir}

        zip -r ${distdir} ${distdir}
        echo "--- Contents of ${distdir}.zip ---"
        unzip -l ${distdir}.zip
    else
        echo "Directory ${whldir} does not exist."
    fi
done