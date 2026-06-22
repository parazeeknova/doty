import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property var ports: []
    property var filteredPorts: []
    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

    function filterPorts() {
        if (searchQuery.trim() === "") {
            filteredPorts = ports;
        } else {
            var temp = [];
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < ports.length; i++) {
                var p = ports[i];
                if (p.protocol.toLowerCase().indexOf(query) !== -1 || p.port.indexOf(query) !== -1 || p.process.toLowerCase().indexOf(query) !== -1 || p.pid.indexOf(query) !== -1)
                    temp.push(p);

            }
            filteredPorts = temp;
        }
        selectedIndex = 0;
    }

    function killPort(pid) {
        killProc.pid = pid;
        killProc.running = true;
    }

    Component.onCompleted: getPortsProc.running = true

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "ports_popup"
    }

    Process {
        id: getPortsProc

        command: [root.homeDir + "/.config/quickshell/ports_popup/get_ports_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.ports = data.ports || [];
                    root.filterPorts();
                } catch (e) {
                    console.log("Failed to parse ports: " + e);
                }
            }
        }

    }

    Process {
        id: killProc

        property string pid: ""

        command: ["sh", "-c", "kill -9 " + pid + " && notify-send -t 1500 -h string:x-canonical-private-synchronous:port-kill -a \"Ports\" -i \"process-stop\" \"Killed process\" \"PID " + pid + " terminated\" || notify-send -t 1500 -h string:x-canonical-private-synchronous:port-kill -a \"Ports\" -i \"dialog-error\" \"Failed\" \"Could not kill PID " + pid + "\""]
        running: false
        onExited: {
            getPortsProc.running = true;
        }
    }

    Timer {
        id: searchDebounce

        interval: 150
        repeat: false
        onTriggered: root.filterPorts()
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetY: -350
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: 320
                implicitHeight: Math.min(260, 32 + portsList.contentHeight + bottomRow.implicitHeight)
                Component.onCompleted: {
                    introAnim.start();
                    searchInput.forceActiveFocus();
                }

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: win.animOffsetY
                    left: 32
                }

                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: -350
                        to: 4
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: 4
                        to: -350
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        console.log("ports_popup: focus grab cleared, closing popup");
                        win.closePopup();
                    }
                }

                Rectangle {
                    id: mainContainer

                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;
                            else
                                root.selectedIndex = root.filteredPorts.length - 1;
                            portsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.filteredPorts.length - 1)
                                root.selectedIndex++;
                            else
                                root.selectedIndex = 0;
                            portsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredPorts.length > 0)
                                root.killPort(root.filteredPorts[root.selectedIndex].pid);

                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (root.filteredPorts.length > 0)
                                root.killPort(root.filteredPorts[root.selectedIndex].pid);

                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Search Bar (Underline only, matching rofi inputbar)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 16
                            color: "transparent"

                            TextInput {
                                id: searchInput

                                anchors.fill: parent
                                anchors.bottomMargin: 2
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.accent
                                font.family: root.fontName
                                font.pointSize: 8
                                focus: true
                                onTextChanged: {
                                    root.searchQuery = text.toLowerCase();
                                    searchDebounce.restart();
                                }

                                Text {
                                    text: "filter ports..."
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    visible: searchInput.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                            // Underline
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: searchInput.activeFocus ? theme.accent : theme.secondary
                            }

                        }

                        // List view
                        ListView {
                            id: portsList

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.filteredPorts
                            spacing: 2

                            header: Item {
                                width: portsList.width
                                height: 20

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "proto"
                                        width: 44
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "port"
                                        width: 50
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "process"
                                        width: 100
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "pid"
                                        width: 48
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "address"
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: theme.secondary
                                    opacity: 0.15
                                }

                            }

                            delegate: Rectangle {
                                width: portsList.width
                                height: 16
                                color: (root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4

                                    Text {
                                        text: modelData.protocol
                                        width: 44
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.port
                                        width: 50
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.process
                                        width: 100
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.pid
                                        width: 48
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.7 : 0.5
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.address
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        elide: Text.ElideRight
                                        opacity: root.selectedIndex === index ? 0.7 : 0.5
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.killPort(modelData.pid)
                                }

                            }

                        }

                        // Bottom Row (total ports & refresh)
                        RowLayout {
                            id: bottomRow

                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4

                            Text {
                                text: root.filteredPorts.length + " ports"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "refresh"
                                font.family: root.fontName
                                font.pointSize: 8
                                color: refreshMouseArea.containsMouse ? theme.accent : theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    id: refreshMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        getPortsProc.running = true;
                                    }
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
