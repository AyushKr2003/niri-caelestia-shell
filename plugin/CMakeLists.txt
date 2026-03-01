find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick Concurrent Multimedia Network Sql)

if(QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()

string(REGEX MATCH "^[0-9]+\\.[0-9]+" VERSION_SHORT "${VERSION}")

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup()
add_subdirectory(src/Caelestia)
