cmake_minimum_required(VERSION 3.16)

project(testqt VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI on)

find_package(Qt6 6.2 COMPONENTS Quick REQUIRED)

qt_add_executable(apptestqt
    main.cpp
)

qt_add_qml_module(apptestqt
    URI testqt
    VERSION 1.0
    QML_FILES main.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(apptestqt PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.apptestqt
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(apptestqt
    PRIVATE Qt6::Quick)

include(GNUInstallDirs)
install(TARGETS apptestqt
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
