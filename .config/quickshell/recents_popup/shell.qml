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
    property var clients: []
    property var filteredClients: []
    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

    function filterClients() {
        if (searchQuery.trim() === "") {
            filteredClients = clients;
        } else {
            var temp = [];
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < clients.length; i++) {
                var c = clients[i];
                if (c.title.toLowerCase().indexOf(query) !== -1 || c.class.toLowerCase().indexOf(query) !== -1 || c.workspace_roman.toLowerCase().indexOf(query) !== -1)
                    temp.push(c);

            }
            filteredClients = temp;
        }
        selectedIndex = 0;
    }

    function focusWorkspace(wsId) {
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

    Component.onCompleted: getRecentsProc.running = true

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "recents_popup"
    }

    Process {
        id: getRecentsProc

        command: [root.homeDir + "/.config/quickshell/recents_popup/get_recents_list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.clients = data.clients || [];
                    root.filterClients();
                } catch (e) {
                    console.log("Failed to parse recents: " + e);
                }
            }
        }

    }

    Timer {
        id: searchDebounce

        interval: 150
        repeat: false
        onTriggered: root.filterClients()
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
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: 240
                implicitHeight: Math.min(300, 32 + recentsList.contentHeight + bottomRow.implicitHeight)
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
                        console.log("recents_popup: focus grab cleared, closing popup");
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
                                root.selectedIndex = root.filteredClients.length - 1;
                            recentsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.filteredClients.length - 1)
                                root.selectedIndex++;
                            else
                                root.selectedIndex = 0;
                            recentsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredClients.length > 0)
                                root.focusWorkspace(root.filteredClients[root.selectedIndex].workspace_id);

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
                                    text: "filter recents..."
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
                            id: recentsList

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.filteredClients
                            spacing: 4

                            delegate: Rectangle {
                                width: recentsList.width
                                height: 38
                                color: (root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    spacing: 6

                                    // Window Live Preview
                                    Rectangle {
                                        id: previewContainer

                                        width: 56
                                        height: 32
                                        color: "#161616"
                                        border.width: 1
                                        border.color: root.selectedIndex === index ? theme.accent : theme.bg_light
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
                                                width: 56
                                                height: 32
                                                constraintSize: Qt.size(width, height)
                                            }

                                        }

                                        // App Icon Badge in the Center
                                        Rectangle {
                                            width: 12
                                            height: 12
                                            color: theme.popupBgColor
                                            radius: 0
                                            anchors.centerIn: parent

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                fillMode: Image.PreserveAspectFit
                                                source: root.getWindowIconPath(modelData)
                                            }

                                        }

                                    }

                                    // Text Info Column
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - previewContainer.width - 14
                                        spacing: 1

                                        // First line: Class and Workspace
                                        Row {
                                            spacing: 6

                                            Text {
                                                text: modelData.class.toLowerCase()
                                                color: root.selectedIndex === index ? theme.accent : theme.secondary
                                                font.family: root.fontName
                                                font.pointSize: 6.5
                                                font.bold: true
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                text: "[" + modelData.workspace_roman + "]"
                                                color: theme.secondary
                                                font.family: root.fontName
                                                font.pointSize: 6.5
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Second line: Window Title
                                        Text {
                                            text: modelData.title.toLowerCase()
                                            color: root.selectedIndex === index ? theme.accent : theme.fg
                                            font.family: root.fontName
                                            font.pointSize: 6.5
                                            elide: Text.ElideRight
                                            width: parent.width
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.focusWorkspace(modelData.workspace_id)
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
                                text: root.filteredClients.length + " active windows"
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
                                        getRecentsProc.running = true;
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
