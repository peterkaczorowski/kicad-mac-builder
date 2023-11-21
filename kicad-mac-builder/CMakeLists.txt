cmake_minimum_required( VERSION 3.6.2 )
project( KiCadMacBuilder )

cmake_policy(SET CMP0135 NEW)

include( ExternalProject )

if( NOT DEFINED KICAD_CMAKE_BUILD_TYPE )
    message( FATAL_ERROR "KICAD_CMAKE_BUILD_TYPE must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED KICAD_TAG AND NOT DEFINED KICAD_SOURCE_DIR)
    message( FATAL_ERROR "KICAD_TAG or KICAD_SOURCE_DIR must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED PACKAGES3D_TAG )
    message( FATAL_ERROR "PACKAGES3D_TAG must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED FOOTPRINTS_TAG )
    message( FATAL_ERROR "FOOTPRINTS_TAG must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED SYMBOLS_TAG )
    message( FATAL_ERROR "SYMBOLS_TAG must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED DOCS_TARBALL_URL)
    message( FATAL_ERROR "DOCS_TARBALL_URL must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED TEMPLATES_TAG)
    message( FATAL_ERROR "TEMPLATES_TAG must be set.  Please see the README or try build.py." )
endif ()
if( NOT DEFINED SKIP_DOCS_UPDATE )
    set( SKIP_DOCS_UPDATE OFF )
endif ()

if( NOT DEFINED MACOS_MIN_VERSION )
    message( FATAL_ERROR "MACOS_MIN_VERSION must be set.  Please see the README or try build.py." )
endif ()

if( NOT DEFINED SIGNING_CERTIFICATE_ID )
    set( SIGNING_CERTIFICATE_ID - )
endif ()

if( HARDENED_RUNTIME )
    set( HARDENED_RUNTIME_ARG "--hardened-runtime")
endif()

if( NOT DEFINED DMG_DIR )
    set( DMG_DIR ${CMAKE_BINARY_DIR}/dmg )
endif ()

set( CMAKE_VERBOSE_MAKEFILE ON )
set( BIN_DIR ${CMAKE_SOURCE_DIR}/bin )

set( SYMBOLS_URL https://gitlab.com/kicad/libraries/kicad-symbols.git )
set( PACKAGES3D_URL https://gitlab.com/kicad/libraries/kicad-packages3D.git )
set( TEMPLATES_URL https://gitlab.com/kicad/libraries/kicad-templates.git )
set( FOOTPRINTS_URL https://gitlab.com/kicad/libraries/kicad-footprints.git )

set( PYTHON_VERSION 3.9.13 )
set( PYTHON_X_Y_VERSION 3.9 )
set( PYTHON_INSTALL_DIR ${CMAKE_BINARY_DIR}/python-dest/Library/Frameworks ) # Ending in /Library/Frameworks is important here

set( wxwidgets_INSTALL_DIR ${CMAKE_BINARY_DIR}/wxwidgets-dest )

set( ngspice_INSTALL_DIR ${CMAKE_BINARY_DIR}/ngspice-dest )

set( KICAD_INSTALL_DIR ${CMAKE_BINARY_DIR}/kicad-dest )

set( KICAD_CMAKE_ARGS -DDEFAULT_INSTALL_PATH=/Library/Application\ Support/kicad )

# Add the FFTW directory to the extra bundle dirs, for ngspice
execute_process(COMMAND brew --prefix fftw OUTPUT_VARIABLE BREW_FFTW_BASEDIR RESULT_VARIABLE FOUND_BREW_FFTW_BASEDIR_EXIT_CODE OUTPUT_STRIP_TRAILING_WHITESPACE)
if ( ${FOUND_BREW_FFTW_BASEDIR_EXIT_CODE} EQUAL 0 )
    get_filename_component(BREW_FFTW_LIBRARY_DIR ${BREW_FFTW_BASEDIR}/lib/ REALPATH DIRECTORY)
    set( MACOS_EXTRA_BUNDLE_FIX_DIRS ${MACOS_EXTRA_BUNDLE_FIX_DIRS} ${BREW_FFTW_LIBRARY_DIR} )
endif()

# FindOpenCASCADE.cmake finds /usr/local/lib, but not the Homebrew one.  fixup_bundle doesn't work with /usr/local/lib as a dirs argument, so
# if OCC is installed by brew, we're going to pass in the library and include dir manually. If not, we aren't passing in anything
# which means that FindOpenCASCADE.cmake will do its regular job.
# This should be fixed by figuring out why fixup_bundle isn't working with /usr/local/lib in the dirs argument.

execute_process(COMMAND brew --prefix opencascade OUTPUT_VARIABLE BREW_OCC_BASEDIR RESULT_VARIABLE FOUND_BREW_OCC_BASEDIR_EXIT_CODE OUTPUT_STRIP_TRAILING_WHITESPACE)
if ( ${FOUND_BREW_OCC_BASEDIR_EXIT_CODE} EQUAL 0 )
    get_filename_component(BREW_LIBTKERNEL_REALPATH ${BREW_OCC_BASEDIR}/lib/libTKernel.dylib REALPATH)
    get_filename_component(BREW_OCC_LIBRARY_DIR ${BREW_LIBTKERNEL_REALPATH} DIRECTORY)
    get_filename_component(BREW_OCC_INCLUDE_DIR ${BREW_OCC_BASEDIR}/include/opencascade REALPATH)
    message( "OpenCascade appears to have been installed by brew." )
    message("BREW_LIBTKERNEL_REALPATH: ${BREW_LIBTKERNEL_REALPATH}" )
    message("BREW_OCC_LIBRARY_DIR: ${BREW_OCC_LIBRARY_DIR}" )
    message("BREW_OCC_INCLUDE_DIR: ${BREW_OCC_INCLUDE_DIR}" )
    set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DOCC_INCLUDE_DIR=${BREW_OCC_INCLUDE_DIR} -DOCC_LIBRARY_DIR=${BREW_OCC_LIBRARY_DIR} )
endif()

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${KICAD_INSTALL_DIR} )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DCMAKE_C_COMPILER=/usr/bin/clang )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DCMAKE_CXX_COMPILER=/usr/bin/clang++ )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOS_MIN_VERSION} )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DwxWidgets_CONFIG_EXECUTABLE=${wxwidgets_INSTALL_DIR}/bin/wx-config )

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DKICAD_BUILD_I18N=ON )

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DKICAD_SCRIPTING_WXPYTHON=ON )

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DPYTHON_EXECUTABLE=${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/bin/python3 )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DPYTHON_INCLUDE_DIR=${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/include/python${PYTHON_X_Y_VERSION}/ )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DPYTHON_LIBRARY=${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/lib/libpython${PYTHON_X_Y_VERSION}.dylib )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DPYTHON_SITE_PACKAGE_PATH=${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/lib/python${PYTHON_X_Y_VERSION}/site-packages )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DPYTHON_FRAMEWORK=${PYTHON_INSTALL_DIR}/Python.framework )

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DNGSPICE_INCLUDE_DIR=${ngspice_INSTALL_DIR}/include )
set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DNGSPICE_LIBRARY=${ngspice_INSTALL_DIR}/lib/libngspice.dylib )

set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DCMAKE_BUILD_TYPE=${KICAD_CMAKE_BUILD_TYPE} )

if(${KICAD_VERSION_EXTRA})
    set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} -DKICAD_VERSION_EXTRA=${KICAD_VERSION_EXTRA} )
endif()

if(DEFINED KICAD_CMAKE_ARGS_EXTRA)
    set( KICAD_CMAKE_ARGS ${KICAD_CMAKE_ARGS} ${KICAD_CMAKE_ARGS_EXTRA} )
endif()


# This is not a perfect way to escape the CMake arguments
# it is not clear to me how to escape them perfectly
# The key here was that I needed to escape the space in Application Support

set(PRINTABLE_KICAD_CMAKE_ARGS "")
foreach(line IN LISTS KICAD_CMAKE_ARGS)
    string(REPLACE " " "\\ " line "${line}")
    string(APPEND PRINTABLE_KICAD_CMAKE_ARGS "${line}\n")
endforeach()

message( "CMake Setting Summary for kicad-mac-builder" )
message( "KICAD_TAG: ${KICAD_TAG}" )
message( "KICAD_SOURCE_DIR: ${KICAD_SOURCE_DIR}" )
message( "PACKAGES3D_TAG: ${PACKAGES3D_TAG}" )
message( "SYMBOLS_TAG: ${SYMBOLS_TAG}" )
message( "FOOTPRINTS_TAG: ${FOOTPRINTS_TAG}" )
message( "TEMPLATES_TAG: ${TEMPLATES_TAG}" )
message( "DOCS_TARBALL_URL: ${DOCS_TARBALL_URL}" )
message( "SYMBOLS_URL: ${SYMBOLS_URL}" )
message( "FOOTPRINTS_URL: ${FOOTPRINTS_URL}" )
message( "PACKAGES3D_URL: ${PACKAGES3D_URL}" )
message( "TEMPLATES_URL: ${TEMPLATES_URL}" )
message( "KICAD_CMAKE_ARGS: ${PRINTABLE_KICAD_CMAKE_ARGS}" )


include( python.cmake )
include( wx.cmake )
include( ngspice.cmake)
include( docs.cmake )

include( footprints.cmake )
include( symbols.cmake )
include( templates.cmake )
include( packages3d.cmake )

include( kicad.cmake )

include( package_kicad_nightly.cmake )
include( package_kicad_unified.cmake )
include( package_extras.cmake )
