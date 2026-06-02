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
    property string activeWindowAddress: ""
    property var visibleWorkspaceIds: [1, 2]
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
    property bool dragMoved: false
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

    signal requestClose()

    // Update Hyprland info
    function updateAll() {
        getClients.running = true;
        getMonitors.running = true;
        getActiveWorkspace.running = true;
        getActiveWindow.running = true;
    }

    function normalizeAddress(address) {
        if (!address)
            return "";

        var addressString = String(address).toLowerCase();
        if (!addressString.startsWith("0x"))
            addressString = "0x" + addressString;

        return addressString;
    }

    function rebuildVisibleWorkspaceIds() {
        var workspaceMap = {
        };
        var activeId = Math.max(1, root.activeWorkspaceId);
        var maxId = activeId;
        workspaceMap[activeId] = true;
        for (var i = 0; i < root.windowList.length; i++) {
            var win = root.windowList[i];
            var wsId = (win && win.workspace) ? win.workspace.id : -1;
            if (wsId > 0) {
                workspaceMap[wsId] = true;
                maxId = Math.max(maxId, wsId);
            }
        }
        if (maxId < 10) {
            workspaceMap[maxId + 1] = true;
            maxId = maxId + 1;
        } else {
            workspaceMap[9] = true;
        }
        var ids = [];
        for (var id = 1; id <= maxId; id++) {
            if (workspaceMap[id])
                ids.push(id);

        }
        root.visibleWorkspaceIds = ids.length > 0 ? ids : [1];
    }

    // Helper functions
    function getToplevelForAddress(address) {
        const values = ToplevelManager.toplevels.values;
        const targetAddr = root.normalizeAddress(address);
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
        for (var i = 0; i < root.visibleWorkspaceIds.length; i++) {
            var cell = repeater.itemAt(i);
            if (cell) {
                var cellPt = container.mapToItem(cell, globalX, globalY);
                if (cellPt.x >= 0 && cellPt.x <= cell.width && cellPt.y >= 0 && cellPt.y <= cell.height)
                    return cell.wsId;

            }
        }
        return -1;
    }

    function getVisualGeometry(wsId, modelData, scale) {
        return {
            "x": Math.round(modelData.at[0] * scale),
            "y": Math.round(modelData.at[1] * scale),
            "width": Math.max(Math.round(modelData.size[0] * scale), 12),
            "height": Math.max(Math.round(modelData.size[1] * scale), 12),
            "opacity": (root.dragActive && root.draggedAddress === modelData.address) ? 0.85 : 0.8
        };
    }

    function iconExists(iconName) {
        if (!iconName)
            return false;

        var path = Quickshell.iconPath(iconName, true);
        return path && path.length > 0 && !String(path).includes("image-missing");
    }

    function iconFromString(value) {
        if (!value)
            return "";

        var name = String(value);
        var entry = DesktopEntries.byId(name);
        if (entry && entry.icon && root.iconExists(entry.icon))
            return entry.icon;

        var substitutions = {
            "code": "visual-studio-code",
            "code-url-handler": "visual-studio-code",
            "code-insiders": "visual-studio-code-insiders",
            "codium": "vscodium",
            "footclient": "foot",
            "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome",
            "kitty": "kitty",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "steam": "steam",
            "thunar": "org.xfce.thunar",
            "vesktop": "vesktop",
            "wezterm": "org.wezfurlong.wezterm",
            "zen": "zen-browser"
        };
        var lower = name.toLowerCase();
        if (substitutions[name] && root.iconExists(substitutions[name]))
            return substitutions[name];

        if (substitutions[lower] && root.iconExists(substitutions[lower]))
            return substitutions[lower];

        if (root.iconExists(name))
            return name;

        if (root.iconExists(lower))
            return lower;

        var lastDomainPart = name.split(".").pop();
        if (root.iconExists(lastDomainPart))
            return lastDomainPart;

        if (root.iconExists(lastDomainPart.toLowerCase()))
            return lastDomainPart.toLowerCase();

        var kebab = lower.replace(/\s+/g, "-").replace(/_/g, "-");
        if (root.iconExists(kebab))
            return kebab;

        var heuristicEntry = DesktopEntries.heuristicLookup(name);
        if (heuristicEntry && heuristicEntry.icon && root.iconExists(heuristicEntry.icon))
            return heuristicEntry.icon;

        return "";
    }

    function getWindowIconPath(win) {
        var candidates = [win ? win.class : "", win ? win.initialClass : "", win ? win.initialTitle : "", win ? win.title : ""];
        for (var i = 0; i < candidates.length; i++) {
            var iconName = root.iconFromString(candidates[i]);
            if (iconName) {
                if (iconName.startsWith("/"))
                    return "file://" + iconName;

                return "image://icon/" + iconName;
            }
        }
        return "image://icon/application-x-executable";
    }

    Component.onCompleted: {
        updateAll();
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "workspace_popup"
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
                        win.address = root.normalizeAddress(win.address);
                        temp[win.address] = win;
                    }
                    root.windowByAddress = temp;
                    root.rebuildVisibleWorkspaceIds();
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
                    root.rebuildVisibleWorkspaceIds();
                } catch (e) {
                    console.log("Error parsing active workspace: " + e);
                }
            }
        }

    }

    Process {
        id: getActiveWindow

        command: ["hyprctl", "activewindow", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.activeWindowAddress = root.normalizeAddress(parsed.address);
                } catch (e) {
                    root.activeWindowAddress = "";
                    console.log("Error parsing active window: " + e);
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
                implicitHeight: Math.max(mainColumn.implicitHeight + 24, 0)
                Component.onCompleted: introAnim.start()

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                // Layout: Top Left Sidebar Popup with margins
                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: 4
                    left: win.animOffsetX
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetX"
                        from: -550
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
                        property: "animOffsetX"
                        from: 32
                        to: -550
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
                    color: theme.popupBgColor
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
                            rows: Math.ceil(root.visibleWorkspaceIds.length / 2)
                            rowSpacing: 8 // Concise spacing
                            columnSpacing: 8

                            Repeater {
                                id: wsGridRepeater

                                model: root.visibleWorkspaceIds.length

                                delegate: Rectangle {
                                    id: wsCell

                                    readonly property int wsId: root.visibleWorkspaceIds[index]

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
                                        enabled: !root.dragActive
                                        onClicked: {
                                            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsCell.wsId + "})"]);
                                            win.closePopup();
                                        }
                                    }

                                    DropArea {
                                        anchors.fill: parent
                                        onEntered: {
                                            root.hoveredWorkspaceId = wsCell.wsId;
                                        }
                                        onExited: {
                                            if (root.hoveredWorkspaceId === wsCell.wsId)
                                                root.hoveredWorkspaceId = -1;

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
                                                property bool grabbed: false
                                                property var homeParent: null

                                                // Scale geometry
                                                x: grabbed ? root.dragX : root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).x
                                                y: grabbed ? root.dragY : root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).y
                                                width: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).width
                                                height: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).height
                                                color: "transparent"
                                                border.width: grabbed || root.activeWindowAddress === root.normalizeAddress(modelData.address) ? 1 : 0
                                                border.color: root.colorTheme
                                                radius: 0 // Sharp corners
                                                clip: true
                                                opacity: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).opacity
                                                scale: grabbed ? 0.95 : 1
                                                z: grabbed ? 9999 : 1
                                                Drag.active: grabbed
                                                Drag.source: winPreview
                                                Drag.hotSpot.x: root.dragOffsetX
                                                Drag.hotSpot.y: root.dragOffsetY

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
                                                    color: theme.popupBgColor
                                                    border.width: 0
                                                    radius: 0
                                                    anchors.centerIn: parent

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 1
                                                        fillMode: Image.PreserveAspectFit
                                                        source: root.getWindowIconPath(winPreview.modelData)
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
                                                        root.dragMoved = false;
                                                        root.draggedWidth = winPreview.width;
                                                        root.draggedHeight = winPreview.height;
                                                        var globalPt = mapToItem(contentContainer, mouse.x, mouse.y);
                                                        root.dragOffsetX = mouse.x;
                                                        root.dragOffsetY = mouse.y;
                                                        root.dragX = globalPt.x - mouse.x;
                                                        root.dragY = globalPt.y - mouse.y;
                                                        winPreview.homeParent = winPreview.parent;
                                                        winPreview.parent = contentContainer;
                                                        winPreview.grabbed = true;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed) {
                                                            var globalPt = mapToItem(contentContainer, mouse.x, mouse.y);
                                                            root.dragX = globalPt.x - root.dragOffsetX;
                                                            root.dragY = globalPt.y - root.dragOffsetY;
                                                            root.dragMoved = true;
                                                            root.hoveredWorkspaceId = root.findHoveredWorkspace(contentContainer, globalPt.x, globalPt.y, wsGridRepeater);
                                                        }
                                                    }
                                                    onReleased: {
                                                        var targetWorkspace = root.hoveredWorkspaceId;
                                                        if (root.dragActive) {
                                                            root.dragActive = false;
                                                            if (targetWorkspace !== -1 && targetWorkspace !== root.draggedSourceWorkspace) {
                                                                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + targetWorkspace + ", follow = false, window = \"address:" + root.draggedAddress + "\" })"]);
                                                                root.updateAll();
                                                            }
                                                        }
                                                        winPreview.grabbed = false;
                                                        winPreview.parent = winPreview.homeParent;
                                                        root.draggedWindow = null;
                                                        root.draggedAddress = "";
                                                        root.draggedSourceWorkspace = -1;
                                                        root.hoveredWorkspaceId = -1;
                                                        root.hoveredWindowAddress = "";
                                                    }
                                                    onCanceled: {
                                                        winPreview.grabbed = false;
                                                        if (winPreview.homeParent)
                                                            winPreview.parent = winPreview.homeParent;

                                                        root.dragActive = false;
                                                        root.draggedWindow = null;
                                                        root.draggedAddress = "";
                                                        root.draggedSourceWorkspace = -1;
                                                        root.hoveredWorkspaceId = -1;
                                                        root.hoveredWindowAddress = "";
                                                    }
                                                    onClicked: (mouse) => {
                                                        if (root.dragMoved)
                                                            return ;

                                                        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + winPreview.modelData.address + "\" })"]);
                                                        win.closePopup();
                                                    }
                                                }

                                                // Custom Tooltip Overlay
                                                Rectangle {
                                                    id: tooltip

                                                    visible: winMouseArea.containsMouse && !root.dragActive && !winPreview.grabbed && winPreview.modelData.title !== ""
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
                                                    color: theme.podmanBgColor
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
                                                    enabled: !winPreview.grabbed

                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }

                                                }

                                                Behavior on y {
                                                    enabled: !winPreview.grabbed

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

            }

        }

    }

}
