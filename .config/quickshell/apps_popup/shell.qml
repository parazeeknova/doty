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
    property var apps: []
    property var mostUsed: []
    property var filteredApps: []
    property var activeWindows: []
    property int selectedActiveWindowIndex: -1
    property var displayList: []
    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

    function filterApps() {
        if (searchQuery.trim() === "") {
            filteredApps = apps;
        } else {
            var temp = [];
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i];
                if (app.name.toLowerCase().indexOf(query) !== -1 || app.exec.toLowerCase().indexOf(query) !== -1)
                    temp.push(app);

            }
            filteredApps = temp;
        }
        rebuildDisplayList();
    }

    function rebuildDisplayList() {
        var list = [];
        if (searchQuery.trim() === "") {
            if (root.mostUsed.length > 0) {
                list.push({
                    "type": "header",
                    "name": "most used"
                });
                for (var i = 0; i < root.mostUsed.length; i++) {
                    list.push({
                        "type": "app",
                        "data": root.mostUsed[i]
                    });
                }
                list.push({
                    "type": "separator"
                });
            }
            for (var j = 0; j < filteredApps.length; j++) {
                list.push({
                    "type": "app",
                    "data": filteredApps[j]
                });
            }
        } else {
            for (var k = 0; k < filteredApps.length; k++) {
                list.push({
                    "type": "app",
                    "data": filteredApps[k]
                });
            }
        }
        root.displayList = list;
        selectFirstApp();
    }

    function selectFirstApp() {
        for (var i = 0; i < root.displayList.length; i++) {
            if (root.displayList[i].type === "app") {
                root.selectedIndex = i;
                break;
            }
        }
    }

    function selectNext() {
        var idx = root.selectedIndex;
        while (idx < root.displayList.length - 1) {
            idx++;
            if (root.displayList[idx].type === "app") {
                root.selectedIndex = idx;
                break;
            }
        }
    }

    function selectPrev() {
        var idx = root.selectedIndex;
        while (idx > 0) {
            idx--;
            if (root.displayList[idx].type === "app") {
                root.selectedIndex = idx;
                break;
            }
        }
    }

    function launchApp(appName, execCmd) {
        Quickshell.execDetached([root.homeDir + "/.config/quickshell/apps_popup/get_apps_list", "--launch", appName]);
        Quickshell.execDetached(["sh", "-c", execCmd + " &"]);
        root.requestClose();
    }

    function focusWorkspaceAndClose(wsId) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsId + "})"]);
        root.requestClose();
    }

    function normalizeAddress(address) {
        if (!address)
            return "";

        var addressString = String(address).toLowerCase();
        if (!addressString.startsWith("0x"))
            addressString = "0x" + addressString;

        return addressString;
    }

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
        getAppsProc.running = true;
        getRecentsProc.running = true;
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "apps_popup"
    }

    Process {
        id: getAppsProc

        command: [root.homeDir + "/.config/quickshell/apps_popup/get_apps_list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.mostUsed = data.most_used || [];
                    root.apps = data.all_apps || [];
                    root.filterApps();
                } catch (e) {
                    console.log("Failed to parse apps: " + e);
                }
            }
        }

    }

    Process {
        id: getRecentsProc

        command: [root.homeDir + "/.config/quickshell/recents_popup/get_recents_list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.activeWindows = data.clients || [];
                } catch (e) {
                    console.log("Failed to parse recents in apps_popup: " + e);
                }
            }
        }

    }

    Timer {
        id: searchDebounce

        interval: 150
        repeat: false
        onTriggered: root.filterApps()
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
                implicitWidth: 240
                implicitHeight: Math.min(320, 32 + (activeWindowsArea.visible ? activeWindowsArea.height + 4 : 0) + appsList.contentHeight + bottomRow.implicitHeight)
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
                        console.log("apps_popup: focus grab cleared, closing popup");
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
                        } else if (event.key === Qt.Key_Tab) {
                            if (root.activeWindows.length > 0) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Shift + Tab (backward)
                                    root.selectedActiveWindowIndex--;
                                    if (root.selectedActiveWindowIndex < -1)
                                        root.selectedActiveWindowIndex = root.activeWindows.length - 1;

                                } else {
                                    // Tab (forward)
                                    root.selectedActiveWindowIndex++;
                                    if (root.selectedActiveWindowIndex >= root.activeWindows.length)
                                        root.selectedActiveWindowIndex = -1;

                                }
                                if (root.selectedActiveWindowIndex >= 0)
                                    activeWindowsList.positionViewAtIndex(root.selectedActiveWindowIndex, ListView.Contain);

                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedActiveWindowIndex = -1;
                            root.selectPrev();
                            appsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.selectedActiveWindowIndex = -1;
                            root.selectNext();
                            appsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.selectedActiveWindowIndex >= 0)
                                root.focusWorkspaceAndClose(root.activeWindows[root.selectedActiveWindowIndex].workspace_id);
                            else if (root.displayList.length > 0 && root.displayList[root.selectedIndex] && root.displayList[root.selectedIndex].type === "app")
                                root.launchApp(root.displayList[root.selectedIndex].data.name, root.displayList[root.selectedIndex].data.exec);
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Search Bar (Underline only)
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
                                    text: "search applications..."
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

                        // Active Windows Horizontal Row
                        Rectangle {
                            id: activeWindowsArea

                            Layout.fillWidth: true
                            height: 38
                            color: "transparent"
                            visible: root.activeWindows.length > 0 && root.searchQuery === ""

                            ListView {
                                id: activeWindowsList

                                anchors.fill: parent
                                orientation: ListView.Horizontal
                                spacing: 6
                                model: root.activeWindows
                                clip: true

                                delegate: Rectangle {
                                    width: 36
                                    height: 36
                                    color: "#161616"
                                    border.width: 1
                                    border.color: (root.selectedActiveWindowIndex === index || activeWinMouseArea.containsMouse) ? theme.accent : theme.bg_light
                                    radius: 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Draw the window content live
                                    Loader {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        active: true

                                        sourceComponent: ScreencopyView {
                                            captureSource: root.getToplevelForAddress(modelData.address)
                                            live: true
                                            width: 36
                                            height: 36
                                            constraintSize: Qt.size(width, height)
                                        }

                                    }

                                    // Workspace Badge on Top Right
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.75)
                                        width: workspaceText.implicitWidth + 3
                                        height: 8
                                        radius: 0

                                        Text {
                                            id: workspaceText

                                            anchors.centerIn: parent
                                            text: modelData.workspace_roman
                                            color: theme.accent
                                            font.family: root.fontName
                                            font.pointSize: 4.5
                                            font.bold: true
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                    // App Icon Badge on Bottom Left
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        color: theme.popupBgColor
                                        radius: 0
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.margins: 1

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            fillMode: Image.PreserveAspectFit
                                            source: root.getWindowIconPath(modelData)
                                        }

                                    }

                                    MouseArea {
                                        id: activeWinMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: {
                                            root.selectedActiveWindowIndex = index;
                                        }
                                        onClicked: {
                                            root.focusWorkspaceAndClose(modelData.workspace_id);
                                        }
                                    }

                                }

                            }

                        }

                        // List view
                        ListView {
                            id: appsList

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.displayList
                            spacing: 2

                            delegate: Rectangle {
                                width: appsList.width
                                height: modelData.type === "app" ? 16 : (modelData.type === "header" ? 14 : 5)
                                color: (modelData.type === "app" && root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                // 1. Header Type
                                Item {
                                    visible: modelData.type === "header"
                                    anchors.fill: parent

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name || ""
                                        color: theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // 2. Separator Type
                                Rectangle {
                                    visible: modelData.type === "separator"
                                    width: parent.width
                                    height: 1
                                    color: theme.accent
                                    opacity: 0.25
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 3. App Type
                                Row {
                                    visible: modelData.type === "app"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 6

                                    Text {
                                        text: (modelData.data && modelData.data.name) ? modelData.data.name.toLowerCase() : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        elide: Text.ElideRight
                                        width: 110
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: (modelData.data && modelData.data.exec) ? modelData.data.exec.toLowerCase() : ""
                                        color: root.selectedIndex === index ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        opacity: root.selectedIndex === index ? 0.6 : 0.4
                                        elide: Text.ElideRight
                                        width: appsList.width - 128
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.type === "app"
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = index;
                                        root.selectedActiveWindowIndex = -1;
                                    }
                                    onClicked: root.launchApp(modelData.data.name, modelData.data.exec)
                                }

                            }

                        }

                        // Bottom Row
                        RowLayout {
                            id: bottomRow

                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4

                            Text {
                                text: root.apps.length + " applications found"
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
