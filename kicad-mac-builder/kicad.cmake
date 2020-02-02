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
        DEPENDS python wxpython wxwidgets six ngspice docs
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
        COMMAND cp ${six_DIR}/six.py ${KICAD_INSTALL_DIR}/kicad.app/Contents/Resources/python/site-packages/
)

ExternalProject_Add_Step(
        kicad
        fixup-pcbnew-so
        COMMENT "Fixing loader dependencies so _pcbnew.so works both internal and external to KiCad."
        DEPENDEES install
        COMMAND ${BIN_DIR}/fixup-pcbnew-so.sh  ${KICAD_INSTALL_DIR}/kicad.app/
)

ExternalProject_Add_Step(
	kicad
	verify-pcbnew-so-import
	COMMENT "Verifying python can import _pcbnew.so"
	DEPENDEES fixup-pcbnew-so install-six remove-pyc-and-pyo verify-cli-python verify-app
	COMMAND ${BIN_DIR}/verify-pcbnew-so-import.sh  ${KICAD_INSTALL_DIR}/kicad.app/
)

if(SIGN_KICAD_APP)
	if(NOT DEFINED CERTIFICATE_ID)
		message( FATAL_ERROR "CERTIFICATE_ID must be set if SIGN_KICAD_APP is set." )
	endif()

	#TODO add entitlements

	ExternalProject_Add_Step(
		kicad
		sign
		COMMENT "Signing kicad.app"
		DEPENDEES verify-pcbnew-so-import fixup-pcbnew-so install-six remove-pyc-and-pyo verify-cli-python verify-app
		COMMAND ${BIN_DIR}/apple.py sign --certificate-id ${CERTIFICATE_ID} ${KICAD_INSTALL_DIR}/kicad.app
	)
endif()

if(NOTARIZE_KICAD_APP)
	if(NOT DEFINED APPLE_DEVELOPER_USERNAME OR NOT DEFINED APPLE_DEVELOPER_PASSWORD_KEYCHAIN_NAME OR NOT DEFINED PRIMARY_BUNDLE_ID)
		message( FATAL_ERROR "APPLE_DEVELOPER_USERNAME, APPLE_DEVELOPER_PASSWORD_KEYCHAIN_NAME, and PRIMARY_BUNDLE_ID must be set if NOTARIZE_KICAD_APP is set." )
	endif()

	if((NOTARIZE_KICAD_APP) AND ${SIGN_KICAD_APP})
		set(NOTARIZATION_DEPENDENCIES "sign")
	else()
		set(NOTARIZATION_DEPENDENCIES "fixup-pcbnew-so install-six remove-pyc-and-pyo verify-cli-python verify-app")
	endif()

	ExternalProject_Add_Step(
		kicad
		notarize
		COMMENT "Notarizing kicad.app, if configured"
		DEPENDEES ${NOTARIZATION_DEPENDENCIES}
		COMMAND ${BIN_DIR}/apple.py notarize --apple-developer-username ${APPLE_DEVELOPER_USERNAME} --apple-developer-password-keychain-name ${APPLE_DEVELOPER_PASSWORD_KEYCHAIN_NAME} --primary-bundle-id ${PRIMARY_BUNDLE_ID} ${KICAD_INSTALL_DIR}/kicad.app
)
endif()
