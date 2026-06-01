import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // Hyprland states
    property var windowList: []
    property var windowByAddress: ({
    })
    property var activeWorkspaceId: 1
    property var monitors: []
    property var monitorById: ({
    })
    // Drag and Drop States
    property var draggedWindow: null
    property string draggedAddress: ""
    property int draggedSourceWorkspace: -1
    property bool dragActive: false
    property real dragX: 0
    property real dragY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property int hoveredWorkspaceId: -1
    property real draggedWidth: 80
    property real draggedHeight: 50
    // Concise, Single Color Theme (Gruvbox Material Dark / fg: #d5c4a1)
    readonly property color colorBgDark: "#801d2021"
    // 80% opacity dark bg
    readonly property color colorBgCell: "#282828"
    // Filled workspace cell bg
    readonly property color colorBgCellActive: "#504945"
    // Filled active workspace cell bg
    readonly property color colorBgCellHover: "#665c54"
    // Filled hovered/drop cell bg
    readonly property color colorTheme: "#d5c4a1"
    // The single primary color (fg/borders)
    readonly property color colorThemeLight: "#ebdbb2"
    // High contrast hover color
    readonly property string fontName: "FiraCode Nerd Font"

    // Update Hyprland info
    function updateAll() {
        getClients.running = true;
        getMonitors.running = true;
        getActiveWorkspace.running = true;
    }

    // Helper functions
    function getToplevelForAddress(address) {
        const values = ToplevelManager.toplevels.values;
        const targetAddr = String(address).toLowerCase();
        for (var i = 0; i < values.length; i++) {
            const tl = values[i];
            if (tl.HyprlandToplevel) {
                var tlAddr = tl.HyprlandToplevel.address;
                var tlAddrStr = "";
                if (typeof tlAddr === "number") {
                    tlAddrStr = "0x" + tlAddr.toString(16);
                } else {
                    tlAddrStr = String(tlAddr).toLowerCase();
                    if (!tlAddrStr.startsWith("0x"))
                        tlAddrStr = "0x" + tlAddrStr;

                }
                if (tlAddrStr === targetAddr)
                    return tl;

            }
        }
        return null;
    }

    // Find which workspace cell contains the global coordinates (relative to contentContainer)
    function findHoveredWorkspace(container, globalX, globalY, repeater) {
        for (var i = 0; i < 10; i++) {
            var cell = repeater.itemAt(i);
            if (cell) {
                var cellPt = container.mapToItem(cell, globalX, globalY);
                if (cellPt.x >= 0 && cellPt.x <= cell.width && cellPt.y >= 0 && cellPt.y <= cell.height)
                    return i + 1;

            }
        }
        return -1;
    }

    // Helper to resolve an absolute file path or image provider URI for window class icons
    function getWindowIconPath(winClass) {
        if (!winClass)
            return "";

        var resolve = function resolve(iconName) {
            var p = Quickshell.iconPath(iconName, true);
            if (p) {
                if (p.startsWith("/") && !p.startsWith("file://") && !p.startsWith("image://"))
                    return "file://" + p;

                return p;
            }
            return "";
        };
        // 1. Try DesktopEntries heuristic lookup
        var entry = DesktopEntries.heuristicLookup(winClass);
        if (entry && entry.icon) {
            var r1 = resolve(entry.icon);
            if (r1)
                return r1;

        }
        // 2. Try the cleaned class name (last component)
        var clean = winClass.split(".").pop().toLowerCase();
        var r2 = resolve(clean);
        if (r2)
            return r2;

        // 3. Try raw class name lowercase
        var rawLower = winClass.toLowerCase();
        var r3 = resolve(rawLower);
        if (r3)
            return r3;

        // 4. Try standard substitutions
        var subs = {
            "code-insiders": "visual-studio-code",
            "code": "visual-studio-code",
            "ghostty": "com.mitchellh.ghostty",
            "zen": "zen-browser"
        };
        if (subs[rawLower]) {
            var r4 = resolve(subs[rawLower]);
            if (r4)
                return r4;

        }
        // 5. Fallback to generic icon
        var rFallback = resolve("application-x-executable");
        if (rFallback)
            return rFallback;

        return "";
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        function onRawEvent(event) {
            if (["openlayer", "closelayer", "screencast"].includes(event.name))
                return ;

            updateAll();
        }

        target: Hyprland
    }

    // System processes to query Hyprland state
    Process {
        id: getClients

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.windowList = parsed;
                    var temp = {
                    };
                    for (var i = 0; i < parsed.length; i++) {
                        var win = parsed[i];
                        temp[win.address] = win;
                    }
                    root.windowByAddress = temp;
                } catch (e) {
                    console.log("Error parsing clients: " + e);
                }
            }
        }

    }

    Process {
        id: getMonitors

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.monitors = parsed;
                    var temp = {
                    };
                    for (var i = 0; i < parsed.length; i++) {
                        var mon = parsed[i];
                        temp[mon.id] = mon;
                    }
                    root.monitorById = temp;
                } catch (e) {
                    console.log("Error parsing monitors: " + e);
                }
            }
        }

    }

    Process {
        id: getActiveWorkspace

        command: ["hyprctl", "activeworkspace", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.activeWorkspaceId = parsed.id;
                } catch (e) {
                    console.log("Error parsing active workspace: " + e);
                }
            }
        }

    }

    // Main popup windows (one for each screen)
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetX: -430
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                // Layer Shell Config
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                // Dynamic dimensions based on layout contents
                implicitWidth: 412
                implicitHeight: mainColumn.implicitHeight + 24
                Component.onCompleted: introAnim.start()

                // Layout: Top Left Sidebar Popup with margins
                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: 18
                    left: win.animOffsetX
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetX"
                        from: -430
                        to: 32 // standard left margin of 32px
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
                        property: "animOffsetX"
                        from: 32
                        to: -430
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

                // Auto-close on click outside
                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                // Background container
                Rectangle {
                    id: contentContainer

                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: root.colorBgDark
                    border.width: 1
                    border.color: root.colorTheme
                    radius: 0 // Sharp corners
                    // Listen to Escape key to close
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

                    }

                    // Main Layout
                    Column {
                        id: mainColumn

                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 0

                        // 2x5 Grid of Workspaces (Wider dimensions, directly at the top)
                        GridLayout {
                            id: wsGrid

                            width: parent.width
                            columns: 2
                            rows: 5
                            rowSpacing: 8 // Concise spacing
                            columnSpacing: 8

                            Repeater {
                                id: wsGridRepeater

                                model: 10 // Workspaces 1 to 10

                                delegate: Rectangle {
                                    id: wsCell

                                    readonly property int wsId: index + 1

                                    implicitWidth: 190
                                    implicitHeight: 107
                                    // Filled shades without borders
                                    color: root.hoveredWorkspaceId === wsId ? root.colorBgCellHover : root.activeWorkspaceId === wsId ? root.colorBgCellActive : root.colorBgCell
                                    radius: 0 // Sharp corners
                                    border.width: 0

                                    // Workspace index indicator centered in the middle
                                    Text {
                                        text: String(wsCell.wsId)
                                        font.pixelSize: 16
                                        font.bold: true
                                        font.family: root.fontName
                                        color: root.colorTheme
                                        opacity: 0.7
                                        anchors.centerIn: parent
                                    }

                                    // Interactive Click to Switch Workspace
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsCell.wsId + "})"]);
                                            win.closePopup();
                                        }
                                    }

                                    // Workspace Content (Live Previews)
                                    Item {
                                        id: previewContainer

                                        readonly property real monitorWidth: 1920
                                        readonly property real monitorHeight: 1080
                                        readonly property real scaleX: width / monitorWidth
                                        readonly property real scaleY: height / monitorHeight
                                        readonly property real scale: Math.min(scaleX, scaleY)

                                        anchors.fill: parent
                                        anchors.margins: 1
                                        clip: true

                                        Repeater {
                                            // Filter windows belonging to this workspace
                                            model: root.windowList.filter(function(w) {
                                                return w.workspace.id === wsCell.wsId;
                                            })

                                            delegate: Rectangle {
                                                id: winPreview

                                                required property var modelData

                                                // Scale geometry
                                                x: Math.round((modelData.at[0]) * previewContainer.scale)
                                                y: Math.round((modelData.at[1]) * previewContainer.scale)
                                                width: Math.max(Math.round(modelData.size[0] * previewContainer.scale), 12)
                                                height: Math.max(Math.round(modelData.size[1] * previewContainer.scale), 12)
                                                color: "transparent"
                                                border.width: 0
                                                radius: 0 // Sharp corners
                                                opacity: (root.dragActive && root.draggedAddress === modelData.address) ? 0.3 : 0.8

                                                // Draw the window content live
                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    active: true

                                                    sourceComponent: ScreencopyView {
                                                        captureSource: root.getToplevelForAddress(winPreview.modelData.address)
                                                        live: true
                                                        anchors.fill: parent
                                                    }

                                                }

                                                // App Icon Badge in the Center using file path lookup
                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    color: "#801d2021"
                                                    border.width: 0
                                                    radius: 0
                                                    anchors.centerIn: parent

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 1
                                                        fillMode: Image.PreserveAspectFit
                                                        source: root.getWindowIconPath(winPreview.modelData.class)
                                                    }

                                                }

                                                // Interactive Drag MouseArea
                                                MouseArea {
                                                    id: winMouseArea

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onPressed: (mouse) => {
                                                        root.draggedWindow = root.getToplevelForAddress(winPreview.modelData.address);
                                                        root.draggedAddress = winPreview.modelData.address;
                                                        root.draggedSourceWorkspace = wsCell.wsId;
                                                        root.dragActive = true;
                                                        root.draggedWidth = winPreview.width;
                                                        root.draggedHeight = winPreview.height;
                                                        var globalPt = mapToItem(contentContainer, mouse.x, mouse.y);
                                                        root.dragOffsetX = mouse.x;
                                                        root.dragOffsetY = mouse.y;
                                                        root.dragX = globalPt.x - mouse.x;
                                                        root.dragY = globalPt.y - mouse.y;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed) {
                                                            var globalPt = mapToItem(contentContainer, mouse.x, mouse.y);
                                                            root.dragX = globalPt.x - root.dragOffsetX;
                                                            root.dragY = globalPt.y - root.dragOffsetY;
                                                            // Handle visual collision mapping using the global coordinates helper
                                                            root.hoveredWorkspaceId = root.findHoveredWorkspace(contentContainer, globalPt.x, globalPt.y, wsGridRepeater);
                                                        }
                                                    }
                                                    onReleased: {
                                                        if (root.dragActive) {
                                                            root.dragActive = false;
                                                            if (root.hoveredWorkspaceId !== -1 && root.hoveredWorkspaceId !== root.draggedSourceWorkspace) {
                                                                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + root.hoveredWorkspaceId + ", follow = false, window = \"address:" + root.draggedAddress + "\" })"]);
                                                                root.updateAll();
                                                            }
                                                        }
                                                        root.draggedWindow = null;
                                                        root.draggedAddress = "";
                                                        root.hoveredWorkspaceId = -1;
                                                    }
                                                }

                                                // Custom Tooltip Overlay
                                                Rectangle {
                                                    id: tooltip

                                                    visible: winMouseArea.containsMouse && !root.dragActive && winPreview.modelData.title !== ""
                                                    z: 99999
                                                    parent: contentContainer
                                                    x: {
                                                        var pt = winPreview.mapToItem(contentContainer, 0, 0);
                                                        return Math.min(Math.max(pt.x + (winPreview.width - width) / 2, 8), contentContainer.width - width - 8);
                                                    }
                                                    y: {
                                                        var pt = winPreview.mapToItem(contentContainer, 0, 0);
                                                        return pt.y + winPreview.height + 4;
                                                    }
                                                    width: Math.min(tooltipText.implicitWidth + 8, 200)
                                                    height: tooltipText.implicitHeight + 4
                                                    color: "#e61d2021"
                                                    border.width: 0
                                                    radius: 0

                                                    Text {
                                                        id: tooltipText

                                                        text: winPreview.modelData.title
                                                        color: root.colorTheme
                                                        font.pixelSize: 9
                                                        font.family: root.fontName
                                                        width: parent.width - 8
                                                        elide: Text.ElideRight
                                                        horizontalAlignment: Text.AlignHCenter
                                                        anchors.centerIn: parent
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

                // Global dragged window proxy visualization
                Rectangle {
                    id: dragProxy

                    parent: contentContainer
                    visible: root.dragActive
                    x: root.dragX
                    y: root.dragY
                    width: root.draggedWidth
                    height: root.draggedHeight
                    color: "#b01d2021"
                    border.color: root.colorTheme
                    border.width: 1
                    radius: 0 // Sharp corners
                    z: 9999
                    opacity: 0.8

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 1
                        active: root.dragActive

                        sourceComponent: ScreencopyView {
                            captureSource: root.draggedWindow
                            live: false
                        }

                    }

                    Rectangle {
                        width: 24
                        height: 24
                        color: "#801d2021"
                        border.width: 0
                        radius: 0
                        anchors.centerIn: parent

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            fillMode: Image.PreserveAspectFit
                            source: root.windowByAddress[root.draggedAddress] ? root.getWindowIconPath(root.windowByAddress[root.draggedAddress].class) : ""
                        }

                    }

                }

            }

        }

    }

}
