import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string username: "parazeeknova"
    property int totalContributions: 0
    property var contributionDays: []
    property var contributionActivities: []
    property string hoverInfo: "Hover a cell to see details"
    // Gruvbox color tokens for GitHub contribution levels (Level 0 to 4)
    readonly property var levelColors: [theme.c.bg_dark, "#40d5c4a1", "#80d5c4a1", "#c0d5c4a1", theme.c.fg_light]
    readonly property color textPrimary: theme.c.fg_light // fg
    readonly property color textMuted: "#a89984" // gray
    readonly property color borderColor: theme.c.bg_light // bg1

    Theme {
        id: theme
    }

    // Process to run the Rust helper
    Process {
        id: fetchGraphProc

        command: [root.homeDir + "/.config/quickshell/github_graph/get_github_graph"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.username = data.username || "parazeeknova";
                    root.totalContributions = data.total_contributions || 0;
                    root.contributionDays = data.days || [];
                    root.contributionActivities = data.activity || [];
                } catch (e) {
                    console.log("Failed to parse GitHub graph JSON: " + e);
                }
            }
        }

    }

    // Refresh every 30 minutes
    Timer {
        id: refreshTimer

        interval: 1.8e+06
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchGraphProc.running)
                fetchGraphProc.running = true;

        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: false
                // Set window dimensions
                implicitWidth: 731
                implicitHeight: layout.implicitHeight + 20
                // Layer settings for desktop widget
                WlrLayershell.namespace: "github-graph"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Rectangle {
                    anchors.fill: parent
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: root.borderColor
                    radius: 0 // Sharp, square corners as requested

                    ColumnLayout {
                        id: layout

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 12
                            rightMargin: 12
                            topMargin: 10
                        }
                        spacing: 10

                        // Header Row
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "󰊤 " + root.username
                                color: root.textPrimary
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.totalContributions + " contributions"
                                color: root.textMuted
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                            }

                        }

                        // Grid & Weekday labels
                        RowLayout {
                            spacing: 6

                            // Weekday Labels
                            Column {
                                spacing: 3
                                Layout.alignment: Qt.AlignVCenter

                                // Padding to align with Grid
                                Item {
                                    width: 15 // Sunday (Empty or hidden)
                                    height: 10
                                }

                                Text {
                                    text: "Mon"
                                    color: root.textMuted
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    height: 10
                                }

                                // Tuesday
                                Item {
                                    width: 15
                                    height: 10
                                }

                                Text {
                                    text: "Wed"
                                    color: root.textMuted
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    height: 10
                                }

                                // Thursday
                                Item {
                                    width: 15
                                    height: 10
                                }

                                Text {
                                    text: "Fri"
                                    color: root.textMuted
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    height: 10
                                }

                                // Saturday
                                Item {
                                    width: 15
                                    height: 10
                                }

                            }

                            // The Graph Grid
                            Grid {
                                id: graphGrid

                                rows: 7
                                flow: Grid.TopToBottom
                                spacing: 3

                                Repeater {
                                    model: root.contributionDays.length

                                    delegate: Rectangle {
                                        // Retrieve level safely
                                        property var dayData: root.contributionDays[index]
                                        property int level: dayData ? dayData.level : 0
                                        property string dateStr: dayData ? dayData.date : ""
                                        property int countVal: dayData ? dayData.count : 0

                                        width: 10
                                        height: 10
                                        radius: 0 // Sharp corners as requested
                                        color: root.levelColors[level]
                                        border.width: 1
                                        border.color: "transparent"

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: {
                                                parent.border.color = root.textPrimary;
                                                root.hoverInfo = parent.countVal + " contributions on " + parent.dateStr;
                                            }
                                            onExited: {
                                                parent.border.color = "transparent";
                                                root.hoverInfo = "Hover a cell to see details";
                                            }
                                        }

                                    }

                                }

                            }

                        }

                        // Grid Legend Row
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.hoverInfo
                                color: root.textMuted
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // Legend
                            Row {
                                spacing: 3
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: "Less"
                                    color: root.textMuted
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    rightPadding: 2
                                }

                                Repeater {
                                    model: 5

                                    delegate: Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 0
                                        color: root.levelColors[index]
                                    }

                                }

                                Text {
                                    text: "More"
                                    color: root.textMuted
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    leftPadding: 2
                                }

                            }

                        }

                        // Separator line
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.borderColor
                        }

                        // Activity feed layout
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "Recent Activity"
                                color: root.textPrimary
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                                bottomPadding: 2
                            }

                            Repeater {
                                model: root.contributionActivities

                                delegate: RowLayout {
                                    function getEventIcon(eventType) {
                                        if (eventType === "PushEvent")
                                            return "";

                                        if (eventType === "PullRequestEvent")
                                            return "";

                                        if (eventType === "IssuesEvent")
                                            return "";

                                        if (eventType === "CreateEvent")
                                            return "";

                                        return "";
                                    }

                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: getEventIcon(modelData.event_type)
                                        color: root.textPrimary
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                        Layout.minimumWidth: 12
                                    }

                                    Text {
                                        text: modelData.description + (modelData.count > 1 ? " +" + (modelData.count - 1) : "") + " in "
                                        color: root.textMuted
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: ""
                                        color: root.textPrimary
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: modelData.repo
                                        color: root.textPrimary
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        visible: modelData.total_commits !== undefined
                                        text: ""
                                        color: root.textMuted
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        visible: modelData.total_commits !== undefined
                                        text: modelData.total_commits !== undefined ? modelData.total_commits + (modelData.total_commits === 1 ? " commit" : " commits") : ""
                                        color: root.textMuted
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.underline: true
                                        renderType: Text.NativeRendering
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: " " + modelData.time
                                        color: root.textMuted
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 260
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
