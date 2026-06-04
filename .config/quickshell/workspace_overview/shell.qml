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
    // Theme Colors (matches your popups)
    readonly property color colorBgDark: theme.glassEnabled ? Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.5) : theme.bg
    readonly property color colorBgCell: theme.glassEnabled ? Qt.rgba(theme.bg_dark.r, theme.bg_dark.g, theme.bg_dark.b, 0.5) : theme.bg_dark
    readonly property color colorBgCellActive: theme.glassEnabled ? Qt.rgba(theme.bg_light.r, theme.bg_light.g, theme.bg_light.b, 0.69) : theme.bg_light
    readonly property color colorBgCellHover: theme.glassEnabled ? Qt.rgba(theme.fg_light.r, theme.fg_light.g, theme.fg_light.b, 0.81) : theme.fg_light
    readonly property color colorTheme: theme.accent
    readonly property color colorThemeLight: theme.fg
    readonly property string fontName: "FiraCode Nerd Font"

    // Update Hyprland info
    function updateAll() {
        getClients.running = true;
        getMonitors.running = true;
        getActiveWorkspace.running = true;
        getActiveWindow.running = true;
    }

    function toRoman(num) {
        var lookup = {
            "1": "i",
            "2": "ii",
            "3": "iii",
            "4": "iv",
            "5": "v",
            "6": "vi",
            "7": "vii",
            "8": "viii",
            "9": "ix",
            "10": "x"
        };
        return lookup[num] || String(num);
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

    // Get visual geometry for rendering windows in previews
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

    // Resolve application icon path
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
        target: "workspace_overview"
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

    // Windows list
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
                // Window dimensions wrap the horizontal workspace row layout
                implicitWidth: wsGrid.implicitWidth + 24
                implicitHeight: wsGrid.implicitHeight + 40
                // Desktop widget layer settings
                WlrLayershell.namespace: "workspace-overview"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Centered at the bottom edge of the screen
                anchors {
                    bottom: true
                }

                margins {
                    bottom: 32
                }

                // Background container matching popup styling
                Rectangle {
                    id: contentContainer

                    anchors.fill: parent
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"
                    radius: 0 // Sharp corners

                    // Workspace cells grid centered inside container
                    GridLayout {
                        id: wsGrid

                        columns: root.visibleWorkspaceIds.length
                        rows: 1
                        columnSpacing: 10
                        rowSpacing: 0

                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 8
                        }

                        Repeater {
                            id: wsGridRepeater

                            model: root.visibleWorkspaceIds.length

                            delegate: Rectangle {
                                id: wsCell

                                readonly property int wsId: root.visibleWorkspaceIds[index]

                                implicitWidth: 213
                                implicitHeight: 120
                                color: root.hoveredWorkspaceId === wsId ? root.colorBgCellHover : root.activeWorkspaceId === wsId ? root.colorBgCellActive : root.colorBgCell
                                radius: 0
                                border.width: 0
                                scale: root.hoveredWorkspaceId === wsId ? 1.02 : 1

                                // Workspace label badge
                                Rectangle {
                                    id: wsBadge

                                    width: Math.max(16, badgeText.implicitWidth + 6)
                                    height: 16
                                    color: root.activeWorkspaceId === wsId ? root.colorTheme : theme.bg_dark
                                    border.width: 1
                                    border.color: root.colorTheme
                                    radius: 0
                                    z: 10

                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        topMargin: -5
                                        rightMargin: -5
                                    }

                                    Text {
                                        id: badgeText

                                        anchors.centerIn: parent
                                        text: root.toRoman(wsCell.wsId)
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: root.fontName
                                        color: root.activeWorkspaceId === wsId ? theme.bg : root.colorTheme
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // Interactive Click to Switch Workspace
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.dragActive
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsCell.wsId + "})"]);
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
                                            radius: 0
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

                                            // App Icon Badge in the Center
                                            Rectangle {
                                                width: 18
                                                height: 18
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
                                                    return pt.y - height - 4;
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
                                                    font.pixelSize: 8
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

