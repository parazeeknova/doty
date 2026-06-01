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
    property string hoveredWindowAddress: ""
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

    // Find which window in the hovered workspace cell is hovered by global coordinates
    function findHoveredWindowAddress(container, globalX, globalY, repeater) {
        if (root.hoveredWorkspaceId === -1)
            return "";

        var cell = repeater.itemAt(root.hoveredWorkspaceId - 1);
        if (!cell)
            return "";

        var cellPt = container.mapToItem(cell, globalX, globalY);
        var monitorWidth = 1920;
        var monitorHeight = 1080;
        var pwWidth = cell.width - 2;
        var pwHeight = cell.height - 2;
        var scaleX = pwWidth / monitorWidth;
        var scaleY = pwHeight / monitorHeight;
        var scale = Math.min(scaleX, scaleY);
        var wsWindows = root.windowList.filter(function(w) {
            return w.workspace.id === root.hoveredWorkspaceId;
        });
        for (var i = 0; i < wsWindows.length; i++) {
            var w = wsWindows[i];
            if (w.address === root.draggedAddress)
                continue;

            var wx = Math.round(w.at[0] * scale) + 1;
            var wy = Math.round(w.at[1] * scale) + 1;
            var ww = Math.max(Math.round(w.size[0] * scale), 12);
            var wh = Math.max(Math.round(w.size[1] * scale), 12);
            if (cellPt.x >= wx && cellPt.x <= wx + ww && cellPt.y >= wy && cellPt.y <= wy + wh)
                return w.address;

        }
        return "";
    }

    // Tiling simulation for drag-and-drop visual reflow
    function getSimulatedLayout(wsId) {
        var list = root.windowList.filter(function(w) {
            return w.workspace.id === wsId;
        });
        var isSource = (root.dragActive && wsId === root.draggedSourceWorkspace);
        var isHovered = (root.dragActive && wsId === root.hoveredWorkspaceId);
        var activeWindows = [];
        for (var i = 0; i < list.length; i++) {
            if (root.dragActive && list[i].address === root.draggedAddress)
                continue;

            activeWindows.push(list[i]);
        }
        var draggedItem = root.dragActive ? root.windowByAddress[root.draggedAddress] : null;
        if (isHovered && draggedItem)
            activeWindows.push(draggedItem);

        var layout = {
        };
        var N = activeWindows.length;
        if (N === 1) {
            layout[activeWindows[0].address] = {
                "x": 20,
                "y": 20,
                "width": 1920 - 40,
                "height": 1080 - 40
            };
        } else if (N === 2) {
            layout[activeWindows[0].address] = {
                "x": 20,
                "y": 20,
                "width": 960 - 30,
                "height": 1080 - 40
            };
            layout[activeWindows[1].address] = {
                "x": 960 + 10,
                "y": 20,
                "width": 960 - 30,
                "height": 1080 - 40
            };
        } else if (N >= 3) {
            layout[activeWindows[0].address] = {
                "x": 20,
                "y": 20,
                "width": 960 - 30,
                "height": 1080 - 40
            };
            var rightCount = N - 1;
            var itemHeight = (1080 - 40 - (10 * (rightCount - 1))) / rightCount;
            for (var idx = 1; idx < N; idx++) {
                layout[activeWindows[idx].address] = {
                    "x": 960 + 10,
                    "y": 20 + (idx - 1) * (itemHeight + 10),
                    "width": 960 - 30,
                    "height": itemHeight
                };
            }
        }
        if (isSource && draggedItem)
            layout[draggedItem.address] = {
                "x": draggedItem.at[0],
                "y": draggedItem.at[1],
                "width": draggedItem.size[0],
                "height": draggedItem.size[1],
                "isDraggedSelf": true
            };

        return layout;
    }

    // Resolves coordinates and sizes based on real vs simulated layouts
    function getVisualGeometry(wsId, modelData, scale) {
        var isSource = (root.dragActive && wsId === root.draggedSourceWorkspace);
        var isHovered = (root.dragActive && wsId === root.hoveredWorkspaceId);
        var isIntraSwap = isSource && isHovered && root.hoveredWindowAddress !== "";
        if (!root.dragActive || (!isSource && !isHovered) || isIntraSwap)
            return {
                "x": Math.round(modelData.at[0] * scale),
                "y": Math.round(modelData.at[1] * scale),
                "width": Math.max(Math.round(modelData.size[0] * scale), 12),
                "height": Math.max(Math.round(modelData.size[1] * scale), 12),
                "opacity": (root.dragActive && root.draggedAddress === modelData.address) ? 0.2 : 0.8
            };

        var simLayout = root.getSimulatedLayout(wsId);
        var geom = simLayout[modelData.address];
        if (geom) {
            if (geom.isDraggedSelf)
                return {
                    "x": Math.round(modelData.at[0] * scale),
                    "y": Math.round(modelData.at[1] * scale),
                    "width": Math.max(Math.round(modelData.size[0] * scale), 12),
                    "height": Math.max(Math.round(modelData.size[1] * scale), 12),
                    "opacity": 0.2
                };

            return {
                "x": Math.round(geom.x * scale),
                "y": Math.round(geom.y * scale),
                "width": Math.round(geom.width * scale),
                "height": Math.round(geom.height * scale),
                "opacity": 0.8
            };
        }
        return {
            "x": Math.round(modelData.at[0] * scale),
            "y": Math.round(modelData.at[1] * scale),
            "width": Math.max(Math.round(modelData.size[0] * scale), 12),
            "height": Math.max(Math.round(modelData.size[1] * scale), 12),
            "opacity": 0.8
        };
    }

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
                property real animOffsetX: -550
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
                        from: -550
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
                        to: -550
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
                                    color: root.hoveredWorkspaceId === wsId ? root.colorBgCellHover : root.activeWorkspaceId === wsId ? root.colorBgCellActive : root.colorBgCell
                                    radius: 0 // Sharp corners
                                    border.width: 0
                                    scale: root.hoveredWorkspaceId === wsId ? 1.03 : 1

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
                                                // Shift geometry outwards from the center when a window is hovered over this workspace
                                                readonly property real cellCenterX: previewContainer.width / 2
                                                readonly property real cellCenterY: previewContainer.height / 2
                                                readonly property real winCenterX: Math.round((modelData.at[0]) * previewContainer.scale) + Math.max(Math.round(modelData.size[0] * previewContainer.scale), 12) / 2
                                                readonly property real winCenterY: Math.round((modelData.at[1]) * previewContainer.scale) + Math.max(Math.round(modelData.size[1] * previewContainer.scale), 12) / 2
                                                readonly property bool isSwapTarget: root.hoveredWindowAddress === modelData.address && root.draggedSourceWorkspace === wsCell.wsId
                                                readonly property real offsetX: (root.hoveredWorkspaceId === wsCell.wsId && root.dragActive && root.draggedAddress !== modelData.address && !isSwapTarget) ? (winCenterX > cellCenterX ? 10 : -10) : 0
                                                readonly property real offsetY: (root.hoveredWorkspaceId === wsCell.wsId && root.dragActive && root.draggedAddress !== modelData.address && !isSwapTarget) ? (winCenterY > cellCenterY ? 10 : -10) : 0

                                                // Scale geometry
                                                x: {
                                                    var _active = root.dragActive;
                                                    var _hovered = root.hoveredWorkspaceId;
                                                    var _addr = root.draggedAddress;
                                                    var _swapAddr = root.hoveredWindowAddress;
                                                    if (isSwapTarget) {
                                                        var draggedWin = root.windowByAddress[root.draggedAddress];
                                                        if (draggedWin)
                                                            return Math.round(draggedWin.at[0] * previewContainer.scale);

                                                    }
                                                    return root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).x;
                                                }
                                                y: {
                                                    var _active = root.dragActive;
                                                    var _hovered = root.hoveredWorkspaceId;
                                                    var _addr = root.draggedAddress;
                                                    var _swapAddr = root.hoveredWindowAddress;
                                                    if (isSwapTarget) {
                                                        var draggedWin = root.windowByAddress[root.draggedAddress];
                                                        if (draggedWin)
                                                            return Math.round(draggedWin.at[1] * previewContainer.scale);

                                                    }
                                                    return root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).y;
                                                }
                                                width: {
                                                    var _active = root.dragActive;
                                                    var _hovered = root.hoveredWorkspaceId;
                                                    var _addr = root.draggedAddress;
                                                    var _swapAddr = root.hoveredWindowAddress;
                                                    return root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).width;
                                                }
                                                height: {
                                                    var _active = root.dragActive;
                                                    var _hovered = root.hoveredWorkspaceId;
                                                    var _addr = root.draggedAddress;
                                                    var _swapAddr = root.hoveredWindowAddress;
                                                    return root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).height;
                                                }
                                                color: "transparent"
                                                border.width: root.hoveredWindowAddress === modelData.address ? 1 : 0
                                                border.color: root.colorTheme
                                                radius: 0 // Sharp corners
                                                clip: true
                                                opacity: {
                                                    var _active = root.dragActive;
                                                    var _hovered = root.hoveredWorkspaceId;
                                                    var _addr = root.draggedAddress;
                                                    var _swapAddr = root.hoveredWindowAddress;
                                                    return root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).opacity;
                                                }
                                                scale: (root.dragActive && root.draggedAddress === modelData.address) ? 0.8 : (root.hoveredWindowAddress === modelData.address) ? 0.75 : 1

                                                // Draw the window content live
                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    active: true

                                                    sourceComponent: ScreencopyView {
                                                        captureSource: root.getToplevelForAddress(winPreview.modelData.address)
                                                        live: true
                                                        width: Math.max(Math.round(winPreview.modelData.size[0] * previewContainer.scale), 12)
                                                        height: Math.max(Math.round(winPreview.modelData.size[1] * previewContainer.scale), 12)
                                                        constraintSize: Qt.size(width, height)
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
                                                            if (root.hoveredWorkspaceId === root.draggedSourceWorkspace)
                                                                root.hoveredWindowAddress = root.findHoveredWindowAddress(contentContainer, globalPt.x, globalPt.y, wsGridRepeater);
                                                            else
                                                                root.hoveredWindowAddress = "";
                                                        }
                                                    }
                                                    onReleased: {
                                                        if (root.dragActive) {
                                                            root.dragActive = false;
                                                            if (root.hoveredWorkspaceId !== -1) {
                                                                if (root.hoveredWorkspaceId !== root.draggedSourceWorkspace) {
                                                                    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + root.hoveredWorkspaceId + ", follow = false, window = \"address:" + root.draggedAddress + "\" })"]);
                                                                    root.updateAll();
                                                                } else {
                                                                    if (root.hoveredWindowAddress !== "" && root.hoveredWindowAddress !== root.draggedAddress) {
                                                                        var wsWindows = root.windowList.filter(function(w) {
                                                                            return w.workspace.id === root.hoveredWorkspaceId;
                                                                        });
                                                                        if (wsWindows.length === 2)
                                                                            // Silent swap: move the dragged window to temp workspace 99 and back silently
                                                                            Quickshell.execDetached(["hyprctl", "--batch", "dispatch hl.dsp.window.move({ workspace = 99, follow = false, window = \"address:" + root.draggedAddress + "\" }) ; " + "dispatch hl.dsp.window.move({ workspace = " + root.hoveredWorkspaceId + ", follow = false, window = \"address:" + root.draggedAddress + "\" })"]);
                                                                        else
                                                                            // Fallback for 3+ windows (warps cursor)
                                                                            Quickshell.execDetached(["hyprctl", "--batch", "dispatch hl.dsp.focus({ window = \"address:" + root.draggedAddress + "\" }) ; " + "dispatch hl.dsp.window.swap({ target = \"address:" + root.hoveredWindowAddress + "\" })"]);
                                                                        root.updateAll();
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        root.draggedWindow = null;
                                                        root.draggedAddress = "";
                                                        root.hoveredWorkspaceId = -1;
                                                        root.hoveredWindowAddress = "";
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

                                                Behavior on x {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on y {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on height {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 180
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
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
                    scale: 1

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 1
                        active: root.dragActive

                        sourceComponent: ScreencopyView {
                            captureSource: root.draggedWindow
                            live: false
                            anchors.fill: parent
                            constraintSize: Qt.size(parent.width, parent.height)
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

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

}
