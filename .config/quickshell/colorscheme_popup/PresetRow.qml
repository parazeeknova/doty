import QtQuick
import Quickshell

Rectangle {
    id: presetRow

    property string rowName: ""
    property bool rowActive: false
    property bool rowFocused: false
    property var dotColors: []
    signal triggered()

    height: 14
    color: (presetRow.rowActive || presetRow.rowFocused) ? theme.bg_light : (rowMouse.containsMouse ? theme.bg_light : "transparent")

    // Accent bar on the left edge when keyboard-focused (and not the active preset)
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: theme.accent
        visible: presetRow.rowFocused && !presetRow.rowActive
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: presetRow.triggered()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6

        Text {
            text: presetRow.rowActive ? (presetRow.rowName + " - active") : presetRow.rowName
            color: presetRow.rowActive ? theme.accent : theme.fg_light
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 8
            font.bold: presetRow.rowActive
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
        }

        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            Repeater {
                model: presetRow.dotColors

                delegate: Rectangle {
                    width: 8
                    height: 8
                    color: modelData
                }

            }

        }

    }

}
