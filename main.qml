import QtQuick

Window {
    width: 1280
    height: 720
    maximumWidth: width
    maximumHeight: height

    visible: true
    title: qsTr("Desktop Template")

    Text {
        text: "This is a desktop application template."
        anchors.centerIn: parent
        color: "Black"
        font.pointSize: 20
    }

    MouseArea {
        id: area1
        width: parent.width
        height: parent.height / 3
        onClicked: {
            console.log("MouseArea clicked at: 1");
        }
    }
    MouseArea {
        id: area2
        anchors.top: area1.bottom
        width: parent.width
        height: parent.height / 3
        onClicked: {
            console.log("MouseArea clicked at: 2");
        }
    }
    MouseArea {
        id: area3
        anchors.top: area2.bottom
        width: parent.width
        height: parent.height / 3
        onClicked: {
            console.log("MouseArea clicked at: 3");
        }
    }
}
