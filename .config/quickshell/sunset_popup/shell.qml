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
    property string currentState: ""
    property int selectedIndex: 0
    readonly property var options: [{
        "label": "Auto",
        "key": "auto",
        "temp": ""
    }, {
        "label": "Off",
        "key": "off",
        "temp": ""
    }, {
        "label": "Default",
        "key": "default",
        "temp": "6000K"
    }, {
        "label": "Sunset",
        "key": "sunset",
        "temp": "4500K"
    }, {
        "label": "Night",
        "key": "night",
        "temp": "3500K"
    }, {
        "label": "Midnight",
        "key": "midnight",
        "temp": "2500K"
    }]
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

    function applyOption(key) {
        var stateFile = root.homeDir + "/.config/hypr/sunset.state";
        var confFile = root.homeDir + "/.config/hypr/hyprsunset.conf";
        var osdctl = root.homeDir + "/.config/quickshell/osd/bin/osdctl";
        switch (key) {
        case "off":
            Quickshell.execDetached(["sh", "-c", "> " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset -i && echo -n 'Off' > " + stateFile + " && " + osdctl + " show 'sunset off' info 1200"]);
            break;
        case "sunset":
            Quickshell.execDetached(["sh", "-c", "> " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset -t 4500 && echo -n 'Sunset' > " + stateFile + " && " + osdctl + " show 'sunset 4500k' info 1200"]);
            break;
        case "night":
            Quickshell.execDetached(["sh", "-c", "> " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset -t 3500 && echo -n 'Night' > " + stateFile + " && " + osdctl + " show 'sunset 3500k' info 1200"]);
            break;
        case "midnight":
            Quickshell.execDetached(["sh", "-c", "> " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset -t 2500 && echo -n 'Midnight' > " + stateFile + " && " + osdctl + " show 'sunset 2500k' info 1200"]);
            break;
        case "default":
            Quickshell.execDetached(["sh", "-c", "> " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset -t 6000 && echo -n 'Default' > " + stateFile + " && " + osdctl + " show 'sunset 6000k' info 1200"]);
            break;
        case "auto":
            var autoConf = "profile {\\n    time = 08:00\\n    identity = true\\n}\\nprofile {\\n    time = 18:00\\n    temperature = 5000\\n}\\nprofile {\\n    time = 22:00\\n    temperature = 4000\\n}\\nprofile {\\n    time = 06:00\\n    temperature = 5000\\n}\\n";
            Quickshell.execDetached(["sh", "-c", "printf '" + autoConf + "' > " + confFile + " && killall hyprsunset; sleep 0.1; hyprsunset && echo -n 'Auto' > " + stateFile + " && HOUR=$(date +%H) && if [ $HOUR -ge 22 ] || [ $HOUR -lt 6 ]; then " + osdctl + " show 'sunset auto: 4000k' info 1200; elif [ $HOUR -ge 18 ] || [ $HOUR -lt 8 ]; then " + osdctl + " show 'sunset auto: 5000k' info 1200; else " + osdctl + " show 'sunset auto: off' info 1200; fi"]);
            break;
        }
        root.requestClose();
    }

    Component.onCompleted: getStatusProc.running = true

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "sunset_popup"
    }

    Process {
        id: getStatusProc

        command: [root.homeDir + "/.config/quickshell/sunset_popup/get_sunset_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.currentState = data.current_state || "";
                    for (var i = 0; i < root.options.length; i++) {
                        if (root.options[i].label === root.currentState || root.options[i].key === root.currentState) {
                            root.selectedIndex = i;
                            break;
                        }
                    }
                } catch (e) {
                    console.log("Failed to parse sunset status: " + e);
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
                implicitWidth: 160
                implicitHeight: mainLayout.implicitHeight + 8
                Component.onCompleted: {
                    introAnim.start();
                    mainContainer.forceActiveFocus();
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
                        console.log("sunset_popup: focus grab cleared, closing popup");
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
                                root.selectedIndex = root.options.length - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.options.length - 1)
                                root.selectedIndex++;
                            else
                                root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.applyOption(root.options[root.selectedIndex].key);
                            event.accepted = true;
                        }
                    }

                    Column {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 4
                        spacing: 4

                        // Header (Title)
                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰖚 sunset"
                                color: theme.accent
                                font.family: root.fontName
                                font.pointSize: 8
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                        }

                        // Underline
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                        }

                        // Options list using Repeater
                        Repeater {
                            model: root.options

                            delegate: Rectangle {
                                width: mainLayout.width
                                height: 16
                                color: (root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: (root.currentState && (root.currentState.toLowerCase() === modelData.label.toLowerCase() || root.currentState.toLowerCase() === modelData.key.toLowerCase())) ? "" : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label.toLowerCase()
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.temp ? modelData.temp.toLowerCase() : ""
                                    color: root.selectedIndex === index ? theme.accent : theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 7
                                    opacity: root.selectedIndex === index ? 0.6 : 0.4
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.applyOption(modelData.key)
                                }

                            }

                        }

                        // Bottom Row (current state status)
                        Item {
                            id: bottomRow

                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "current: " + root.currentState.toLowerCase()
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering
                            }

                        }

                    }

                }

            }

        }

    }

}
