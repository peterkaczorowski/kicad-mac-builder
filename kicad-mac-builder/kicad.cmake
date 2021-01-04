include(ExternalProject)

if(DEFINED RELEASE_NAME)
  if(NOT DEFINED KICAD_TAG OR "${KICAD_TAG}" STREQUAL "")
    message( FATAL_ERROR "KICAD_TAG must be set for release builds.  Please see the README or try build.py." )
  endif ()

  ExternalProject_Add(
          kicad
          PREFIX  kicad
          DEPENDS python wxpython wxwidgets six ngspice docs
          GIT_REPOSITORY ${KICAD_URL}
          GIT_TAG ${KICAD_TAG}
          UPDATE_COMMAND          git fetch
          COMMAND                 echo "Making sure we aren't in the middle of a crashed git-am"
          COMMAND                 git am --abort || true
          COMMAND                 git reset --hard ${KICAD_TAG}
          COMMAND                 ${BIN_DIR}/git-multipatch.sh ${CMAKE_SOURCE_DIR}/patches/kicad/*.patch
          COMMAND                 git tag -a ${RELEASE_NAME} -m "${RELEASE_NAME}"
          CMAKE_ARGS  ${KICAD_CMAKE_ARGS}
  )
elseif(NOT DEFINED RELEASE_NAME AND DEFINED KICAD_SOURCE_DIR AND NOT "${KICAD_SOURCE_DIR}" STREQUAL "")
  ExternalProject_Add(
          kicad
          PREFIX  kicad
          DEPENDS python wxpython wxwidgets six ngspice
          SOURCE_DIR ${KICAD_SOURCE_DIR}
          CMAKE_ARGS  ${KICAD_CMAKE_ARGS}
  )
elseif(NOT DEFINED RELEASE_NAME AND DEFINED KICAD_TAG AND NOT "${KICAD_TAG}" STREQUAL "")
  if(NOT DEFINED KICAD_URL OR "${KICAD_URL}" STREQUAL "")
    message( FATAL_ERROR "KICAD_URL must be set if KICAD_TAG is set, but it has a default.  This should never happen." )
  endif ()

  ExternalProject_Add(
        kicad
        PREFIX  kicad
        DEPENDS python wxpython wxwidgets six ngspice docs
        GIT_REPOSITORY ${KICAD_URL}
        GIT_TAG ${KICAD_TAG}
        UPDATE_COMMAND          git fetch
        COMMAND                 echo "Making sure we aren't in the middle of a crashed git-am"
        COMMAND                 git am --abort || true
        COMMAND                 git reset --hard ${KICAD_TAG}
        COMMAND                 ${BIN_DIR}/git-multipatch.sh ${CMAKE_SOURCE_DIR}/patches/kicad/*.patch
        CMAKE_ARGS  ${KICAD_CMAKE_ARGS}
  )
else()
  message( FATAL_ERROR "Either KICAD_TAG or KICAD_SOURCE_DIR must be set.  Please see the README or try build.py." )
endif()

ExternalProject_Add_Step(
        kicad
        install-docs-to-app
        COMMENT "Installing docs into KiCad.app"
        DEPENDS docs
        DEPENDEES install
        COMMAND mkdir -p ${KICAD_INSTALL_DIR}/kicad.app/Contents/SharedSupport/help/
        COMMAND cp -r ${CMAKE_BINARY_DIR}/docs/share/doc/kicad/help/en ${KICAD_INSTALL_DIR}/kicad.app/Contents/SharedSupport/help/
        COMMAND find ${KICAD_INSTALL_DIR}/kicad.app/Contents/SharedSupport/help -name "*.epub" -type f -delete
        COMMAND find ${KICAD_INSTALL_DIR}/kicad.app/Contents/SharedSupport/help -name "*.pdf" -type f -delete
)

ExternalProject_Add_Step(
        kicad
        verify-app
        COMMENT "Checking that all loader dependencies are system-provided or relative"
        DEPENDEES install
        COMMAND ${BIN_DIR}/verify-app.sh ${KICAD_INSTALL_DIR}/kicad.app
)

ExternalProject_Add_Step(
        kicad
        verify-cli-python
        COMMENT "Checking bin/python and bin/pythonw"
        DEPENDEES install
        COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/pythonw
        COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/Python.framework/Versions/2.7/bin/pythonw
        COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python
        COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/Python.framework/Versions/2.7/bin/python
)

ExternalProject_Add_Step(
        kicad
        remove-pyc-and-pyo
        COMMENT "Removing pyc and pyo files"
        DEPENDEES verify-cli-python install-six
        COMMAND find ${KICAD_INSTALL_DIR}/kicad.app/ -type f -name \*.pyc -o -name \*.pyo -delete
)

ExternalProject_Add_Step(
        kicad
        install-six
        COMMENT "Installing six into PYTHONPATH for easier debugging"
        DEPENDEES install
        COMMAND cp ${six_DIR}/six.py ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/python/site-packages/
)

ExternalProject_Add_Step(
        kicad
        fixup-pcbnew-so
        COMMENT "Fixing loader dependencies so _pcbnew.so works both internal and external to KiCad."
        DEPENDEES install
        COMMAND ${BIN_DIR}/fixup-pcbnew-so.sh  ${KICAD_INSTALL_DIR}/kicad.app/Contents/Frameworks/
)

ExternalProject_Add_Step(
        kicad
        resign-invalid-so
        COMMENT "Re-sign invalid signature libraries"
        DEPENDEES fixup-pcbnew-so
        COMMAND ${BIN_DIR}/resign-invalid-so.sh  ${KICAD_INSTALL_DIR}/kicad.app/
)

ExternalProject_Add_Step(
	kicad
	verify-pcbnew-so-import
	COMMENT "Verifying python can import _pcbnew.so"
	DEPENDEES fixup-pcbnew-so install-six remove-pyc-and-pyo verify-cli-python verify-app resign-invalid-so
	COMMAND ${BIN_DIR}/verify-pcbnew-so-import.sh  ${KICAD_INSTALL_DIR}/kicad.app/
)
