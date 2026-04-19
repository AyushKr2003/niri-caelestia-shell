cmake_minimum_required(VERSION 3.16)
project(caelestia VERSION 1.2)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick Concurrent Multimedia Network Sql DBus)


if(QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()

string(REGEX MATCH "^[0-9]+\\.[0-9]+" VERSION_SHORT "${VERSION}")

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup()
add_subdirectory(src/Caelestia)
