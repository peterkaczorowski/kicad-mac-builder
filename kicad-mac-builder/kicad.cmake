include(ExternalProject)

# The idea of kicad-build-deps is that it handles anything that kicad depends upon for building (rather than packaging)
# This should help folks setup build environments easier.

add_custom_target(kicad-build-deps
        DEPENDS python wxpython wxwidgets ngspice
)

add_custom_target(setup-kicad-dependencies
	DEPENDS kicad-build-deps
	COMMENT "kicad-mac-builder would use the following CMake arguments for KiCad in this configuration:\n\n${KICAD_CMAKE_ARGS_FORMATTED}\n\nSee the README for more details."
)


if(DEFINED RELEASE_NAME)
  if(NOT DEFINED KICAD_TAG OR "${KICAD_TAG}" STREQUAL "")
    message( FATAL_ERROR "KICAD_TAG must be set for release builds.  Please see the README or try build.py." )
  endif ()

  ExternalProject_Add(
    kicad
    PREFIX  kicad
    DEPENDS kicad-build-deps docs
    GIT_REPOSITORY ${KICAD_URL}
    GIT_TAG ${KICAD_TAG}
    UPDATE_COMMAND git fetch
    COMMAND git tag -a ${RELEASE_NAME} -m "${RELEASE_NAME}"
    CMAKE_ARGS  ${KICAD_CMAKE_ARGS}
  )
elseif(NOT DEFINED RELEASE_NAME AND DEFINED KICAD_SOURCE_DIR AND NOT "${KICAD_SOURCE_DIR}" STREQUAL "")
  ExternalProject_Add(
    kicad
    PREFIX  kicad
    DEPENDS kicad-build-deps docs
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
    DEPENDS kicad-build-deps docs
    GIT_REPOSITORY ${KICAD_URL}
    GIT_TAG ${KICAD_TAG}
    UPDATE_COMMAND git fetch
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
    COMMAND mkdir -p ${KICAD_INSTALL_DIR}/KiCad.app/Contents/SharedSupport/help/
    COMMAND cp -r ${docs_SOURCE_DIR}/share/doc/kicad/help/ ${KICAD_INSTALL_DIR}/KiCad.app/Contents/SharedSupport/help/
    COMMAND find ${KICAD_INSTALL_DIR}/KiCad.app/Contents/SharedSupport/help -name "*.epub" -type f -delete
    COMMAND find ${KICAD_INSTALL_DIR}/KiCad.app/Contents/SharedSupport/help -name "*.pdf" -type f -delete
)

ExternalProject_Add_Step(
    kicad
    collect-licenses
    COMMENT "Collecting licenses into KiCad.app"
    DEPENDS python
    DEPENDEES install
    COMMAND mkdir -p ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Resources/Licenses
    COMMAND mkdir -p ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Resources/Licenses/Python
    COMMAND cp ${python_BINARY_DIR}/Python.framework/Versions/Current/lib/python${PYTHON_X_Y_VERSION}/LICENSE.txt ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Resources/Licenses/Python/
)

ExternalProject_Add_Step(
    kicad
    fix-loading
    COMMENT "Checking and fixing bundle to make sure it's relocatable"
    DEPENDEES install-docs-to-app install collect-licenses
    # Since we're currently ignoring the exit status, let's make sure wrangle-bundle is installed
    COMMAND echo "Looking for wrangle-bundle..."
    COMMAND which wrangle-bundle
    COMMAND wrangle-bundle --fix --python-version ${PYTHON_X_Y_VERSION} ${KICAD_INSTALL_DIR}/kicad.app || true
)

ExternalProject_Add_Step(
    kicad
    verify-cli-python
    COMMENT "Checking bin/python3"
    DEPENDEES fix-loading
    COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3
    COMMAND ${BIN_DIR}/verify-cli-python.sh ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Frameworks/Python.framework/Versions/${PYTHON_X_Y_VERSION}/bin/python${PYTHON_X_Y_VERSION}
)

ExternalProject_Add_Step(
        kicad
        verify-wx-import
        COMMENT "Verifying python can import wx"
        DEPENDEES verify-cli-python
        COMMAND ${BIN_DIR}/verify-wx-import.sh  ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3
)

ExternalProject_Add_Step(
	kicad
	verify-pcbnew-so-import
	COMMENT "Verifying python can import pcbnew"
	DEPENDEES verify-cli-python
	COMMAND ${BIN_DIR}/verify-pcbnew-so-import.sh  ${KICAD_INSTALL_DIR}/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3
)

if(DEFINED SIGNING_CERTIFICATE_ID)
    ExternalProject_Add_Step(
            kicad
            sign-app
            COMMENT "Signing KiCad.app and its contents"
            DEPENDEES fix-loading # we can't modify KiCad.app after this
            COMMAND "${BIN_DIR}/apple.py" sign --certificate-id "${SIGNING_CERTIFICATE_ID}" --entitlements "${BIN_DIR}/../signing/entitlements.plist" "${KICAD_INSTALL_DIR}/KiCad.app"
    )
    ExternalProject_Add_StepTargets(kicad sign-app)
endif()

if(DEFINED APPLE_DEVELOPER_USERNAME AND DEFINED APPLE_DEVELOPER_PASSWORD_KEYCHAIN_NAME AND DEFINED APP_NOTARIZATION_ID AND DEFINED ASC_PROVIDER)
    ExternalProject_Add_Step(
            kicad
            notarize-app
            COMMENT "Notarize KiCad.app"
            DEPENDEES sign-app
            COMMAND "${BIN_DIR}/apple.py" notarize --apple-developer-username "${APPLE_DEVELOPER_USERNAME}" --apple-developer-password-handle "${APPLE_DEVELOPER_PASSWORD_KEYCHAIN_NAME}" --notarization-id "${APP_NOTARIZATION_ID}" --asc-provider "${ASC_PROVIDER}" "${KICAD_INSTALL_DIR}/KiCad.app"
    )
    ExternalProject_Add_StepTargets(kicad notarize-app)
endif()

