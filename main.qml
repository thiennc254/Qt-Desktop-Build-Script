import QtQuick

Window {
    width: 640
    height: 480
    visible: true
    title: qsTr("Desktop Template")

    Text {
        text: "This is a desktop application template."
        anchors.centerIn: parent
        color: "Black"
        font.pointSize: 20
    }
}
