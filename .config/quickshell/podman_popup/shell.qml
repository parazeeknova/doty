import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property var podmanData: ({
        "containers": [],
        "images": [],
        "networks": []
    })

    signal requestClose()

    function refreshStatus() {
        checkStatusProc.running = false;
        checkStatusProc.running = true;
    }

    function runAction(action, containerId) {
        Quickshell.execDetached(["podman", action, containerId]);
        actionRefreshTimer.restart();
    }

    Component.onCompleted: {
        root.refreshStatus();
    }

    Theme {
        id: theme
    }

    Timer {
        id: actionRefreshTimer

        interval: 500
        repeat: false
        onTriggered: root.refreshStatus()
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "podman_popup"
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: ["/home/parazeeknova/doty/.config/quickshell/podman_popup/get_podman_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.podmanData = data;
                } catch (e) {
                    console.log("Failed to parse Podman status: " + e);
                }
            }
        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -260
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240 // Matches notif_popup width
                implicitHeight: Math.min(500, mainContent.implicitHeight + 20)
                Component.onCompleted: introAnim.start()

                // Refresh every 5 seconds when open
                Timer {
                    interval: 5000
                    repeat: true
                    running: win.visible && !win.isClosing
                    onTriggered: root.refreshStatus()
                }

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    left: true
                }

                margins {
                    left: win.animLeftMargin
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: -260
                        to: 32
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

                // Slide-out + fade-out
                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: 32
                        to: -260
                        duration: 100
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 100
                        easing.type: Easing.InCubic
                    }

                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        win.closePopup();
                    }
                }

                // Main Popup Panel
                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.podmanBgColor // Sleek dark semi-transparent bg matching clipboard
                    border.width: 1
                    border.color: "#d5c4a1"
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    // Content Layout
                    ColumnLayout {
                        id: mainContent

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        // Title (No icon, clean)
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Podman Contianers"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "󰑐"
                                color: refreshMouse.containsMouse ? "#ebdbb2" : "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                MouseArea {
                                    id: refreshMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.refreshStatus()
                                }

                            }

                        }

                        // Scrollable section for data
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: parent.width
                                spacing: 10

                                // SECTION 1: CONTAINERS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Containers"
                                        color: "#ebdbb2"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: false
                                        renderType: Text.NativeRendering
                                    }

                                    Repeater {
                                        model: root.podmanData.containers

                                        delegate: Item {
                                            Layout.fillWidth: true
                                            implicitHeight: containerDetails.implicitHeight

                                            MouseArea {
                                                id: hoverArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }

                                            ColumnLayout {
                                                id: containerDetails

                                                anchors.fill: parent
                                                spacing: 0

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4

                                                    Text {
                                                        text: "●"
                                                        color: (modelData.State === "running") ? "#b8bb26" : "#fb4934"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering
                                                    }

                                                    Text {
                                                        text: (modelData.Names && modelData.Names.length > 0) ? modelData.Names[0] : "Unnamed"
                                                        color: "#d5c4a1"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        renderType: Text.NativeRendering
                                                    }

                                                }

                                                Text {
                                                    text: "├── img: " + (modelData.Image || "N/A")
                                                    color: "#a89984"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    renderType: Text.NativeRendering
                                                }

                                                Text {
                                                    text: ((modelData.Ports && modelData.Ports.length > 0) || hoverArea.containsMouse) ? "├── stat: " + (modelData.Status || "N/A") : "└── stat: " + (modelData.Status || "N/A")
                                                    color: "#a89984"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    renderType: Text.NativeRendering
                                                }

                                                Text {
                                                    visible: modelData.Ports && modelData.Ports.length > 0
                                                    text: hoverArea.containsMouse ? "├── ports: " + (modelData.Ports ? modelData.Ports.map((p) => {
                                                        return p.hostPort + "->" + p.containerPort;
                                                    }).join(", ") : "") : "└── ports: " + (modelData.Ports ? modelData.Ports.map((p) => {
                                                        return p.hostPort + "->" + p.containerPort;
                                                    }).join(", ") : "")
                                                    color: "#ebdbb2"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    renderType: Text.NativeRendering
                                                }

                                                RowLayout {
                                                    visible: hoverArea.containsMouse
                                                    spacing: 6
                                                    Layout.fillWidth: true

                                                    Text {
                                                        text: "└── act:"
                                                        color: "#7c6f64"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering
                                                    }

                                                    Text {
                                                        text: "start"
                                                        color: startMouse.containsMouse ? "#b8bb26" : "#a89984"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            id: startMouse

                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: root.runAction("start", modelData.Id)
                                                        }

                                                    }

                                                    Text {
                                                        text: "stop"
                                                        color: stopMouse.containsMouse ? "#fb4934" : "#a89984"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            id: stopMouse

                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: root.runAction("stop", modelData.Id)
                                                        }

                                                    }

                                                    Text {
                                                        property string actName: (modelData.State === "paused") ? "unpause" : "pause"

                                                        text: actName
                                                        color: pauseMouse.containsMouse ? "#fe8019" : "#a89984"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            id: pauseMouse

                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: root.runAction(parent.actName, modelData.Id)
                                                        }

                                                    }

                                                    Text {
                                                        text: "delete"
                                                        color: deleteMouse.containsMouse ? "#fb4934" : "#a89984"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            id: deleteMouse

                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: root.runAction("rm", modelData.Id)
                                                        }

                                                    }

                                                }

                                            }

                                        }

                                    }

                                    Text {
                                        visible: !root.podmanData.containers || root.podmanData.containers.length === 0
                                        text: " └── none"
                                        color: "#7c6f64"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // SECTION 2: NETWORKS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Networks"
                                        color: "#ebdbb2"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: false
                                        renderType: Text.NativeRendering
                                    }

                                    Repeater {
                                        model: root.podmanData.networks

                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                text: "├─ " + (modelData.name || "N/A") + " (" + (modelData.driver || "N/A") + ")"
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                text: "└─ iface: " + (modelData.network_interface || "N/A") + " | " + ((modelData.subnets && modelData.subnets.length > 0) ? modelData.subnets[0].subnet : "N/A")
                                                color: "#a89984"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                    }

                                    Text {
                                        visible: !root.podmanData.networks || root.podmanData.networks.length === 0
                                        text: " └── none"
                                        color: "#7c6f64"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // SECTION 3: IMAGES
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Images"
                                        color: "#ebdbb2"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: false
                                        renderType: Text.NativeRendering
                                    }

                                    Repeater {
                                        model: root.podmanData.images

                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                text: "├─ " + ((modelData.Names && modelData.Names.length > 0) ? modelData.Names[0] : "Unnamed Image")
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                text: "└─ size: " + (modelData.Size ? (modelData.Size / (1024 * 1024)).toFixed(1) + " MB" : "N/A") + " | " + (modelData.CreatedAt || "N/A")
                                                color: "#a89984"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                    }

                                    Text {
                                        visible: !root.podmanData.images || root.podmanData.images.length === 0
                                        text: " └── none"
                                        color: "#7c6f64"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
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
