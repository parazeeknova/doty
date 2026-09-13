//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    // Spend state (numbers only - keys never enter QML)
    property var accounts: []
    property real capPer: 10.0
    property bool loading: true
    property string loadError: ""
    property double fetchedAt: 0
    property int lastCopiedIdx: -1

    property real totalThis: {
        var t = 0;
        for (var i = 0; i < accounts.length; i++)
            if (accounts[i].this_month >= 0)
                t += accounts[i].this_month;
        return t;
    }
    property real totalPrev: {
        var t = 0;
        for (var i = 0; i < accounts.length; i++)
            if (accounts[i].prev_month >= 0)
                t += accounts[i].prev_month;
        return t;
    }
    property real totalCap: capPer * accounts.length
    property real totalRemaining: Math.max(0, totalCap - totalThis)

    function fmt(v) {
        if (v < 0)
            return "--";
        return "$" + v.toFixed(2);
    }
    function used(a) {
        // Treat sub-cent spend as unused so rounding to $0.00 isn't shown red
        return a.this_month > 0 && Math.round(a.this_month * 100) > 0;
    }
    function monthName(m) {
        return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m];
    }
    property string thisMonthLabel: {
        var d = new Date();
        return monthName(d.getMonth()) + " " + d.getFullYear();
    }
    property string prevMonthLabel: {
        var d = new Date();
        d.setMonth(d.getMonth() - 1);
        return monthName(d.getMonth());
    }
    property string resetLabel: {
        var now = new Date();
        var next = new Date(now.getFullYear(), now.getMonth() + 1, 1);
        var days = Math.max(0, Math.ceil((next - now) / 86400000));
        return "resets in " + days + "d";
    }
    property string updatedLabel: {
        if (!fetchedAt)
            return "";
        var s = Math.max(0, Math.round(Date.now() / 1000 - fetchedAt));
        if (s < 60)
            return "updated " + s + "s ago";
        return "updated " + Math.floor(s / 60) + "m ago";
    }

    function refresh(force) {
        if (checkStatusProc.running || refreshProc.running)
            return;
        root.loading = true;
        root.loadError = "";
        if (force) {
            refreshProc.running = true;
        } else {
            checkStatusProc.running = true;
        }
    }

    function copyKey(idx) {
        copyProc.command = ["sh", "-c", "cat /run/secrets/mg-gateway-key-" + idx + " | wl-copy"];
        copyProc.running = false;
        copyProc.running = true;
        root.lastCopiedIdx = idx;
        copiedTimer.restart();
    }

    Component.onCompleted: refresh(false)

    Process {
        id: checkStatusProc
        command: [homeDir + "/.config/quickshell/mg_popup/get_mg_status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    var data = JSON.parse(this.text);
                    root.accounts = data.accounts || [];
                    root.fetchedAt = data.fetched_at || 0;
                    root.loadError = "";
                } catch (e) {
                    root.loadError = "parse error";
                }
            }
        }
        onExited: {
            if (root.loading) {
                root.loading = false;
                root.loadError = "fetch failed";
            }
        }
    }

    Process {
        id: refreshProc
        command: [homeDir + "/.config/quickshell/mg_popup/get_mg_status", "--refresh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    var data = JSON.parse(this.text);
                    root.accounts = data.accounts || [];
                    root.fetchedAt = data.fetched_at || 0;
                    root.loadError = "";
                } catch (e) {
                    root.loadError = "parse error";
                }
            }
        }
        onExited: {
            if (root.loading) {
                root.loading = false;
                root.loadError = "fetch failed";
            }
        }
    }

    Process {
        id: copyProc
        running: false
    }

    Timer {
        id: copiedTimer
        interval: 1500
        repeat: false
        onTriggered: root.lastCopiedIdx = -1
    }

    IpcHandler {
        target: "mg_popup"
        function close(): void {
            for (var i = 0; i < root.openWindows.length; i++)
                root.openWindows[i].closePopup();
        }
    }

    property var openWindows: []

    Theme {
        id: theme
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -260
                property real animTop: -320
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return;
                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                WlrLayershell.namespace: theme.floatingMode ? "quickshell-top" : "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20
                Component.onCompleted: {
                    introAnim.start();
                    root.openWindows.push(win);
                    keyHandler.forceActiveFocus();
                }
                onVisibleChanged: {
                    if (visible)
                        keyHandler.forceActiveFocus();
                }
                onIsClosingChanged: {
                    if (isClosing) {
                        var idx = root.openWindows.indexOf(win);
                        if (idx !== -1)
                            root.openWindows.splice(idx, 1);
                    }
                }

                anchors {
                    left: !theme.floatingMode
                    bottom: !theme.floatingMode
                    top: theme.floatingMode
                    right: theme.floatingMode
                }
                margins {
                    bottom: 48
                    top: theme.floatingMode ? win.animTop : 0
                    left: theme.floatingMode ? 0 : win.animLeftMargin
                    right: theme.floatingMode ? 8 : 0
                }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animLeftMargin"; from: -260; to: 32; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animTop"; from: -320; to: 22; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    id: exitAnim
                    onStopped: Qt.quit()
                    NumberAnimation { target: win; property: "animLeftMargin"; from: 32; to: -260; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animTop"; from: 22; to: -320; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 100; easing.type: Easing.InCubic }
                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    antialiasing: false
                    focus: true
                    id: keyHandler
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        }
                    }
                    Component.onCompleted: forceActiveFocus()

                    Column {
                        id: mainLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Header: big this-month total + prev month beside it
                        Item {
                            width: parent.width
                            height: 44
                            Row {
                                id: headerRow
                                anchors.left: parent.left
                                anchors.top: parent.top
                                spacing: 8
                                Text {
                                    text: root.loading ? "..." : root.fmt(root.totalThis)
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: theme.fg
                                    renderType: Text.NativeRendering
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0
                                    Text {
                                        text: root.thisMonthLabel + " spend"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.fg_light
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        text: root.prevMonthLabel + " " + root.fmt(root.totalPrev)
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.fg_light
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }
                            Text {
                                text: root.fmt(root.totalRemaining) + " left of " + root.fmt(root.totalCap)
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                color: theme.fg_light
                                renderType: Text.NativeRendering
                                anchors.left: parent.left
                                anchors.top: headerRow.bottom
                                anchors.topMargin: 3
                            }
                            Text {
                                text: "refresh"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                color: refreshMouse.containsMouse ? theme.accent : theme.fg_light
                                renderType: Text.NativeRendering
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    onClicked: root.refresh(true)
                                }
                            }
                        }

                        Text {
                            visible: root.updatedLabel !== ""
                            text: root.updatedLabel
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            color: theme.fg_light
                            renderType: Text.NativeRendering
                        }

                        Rectangle { width: parent.width; height: 1; color: theme.accent; opacity: 0.25 }

                        Text {
                            visible: root.loading
                            text: "fetching spend..."
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            color: theme.fg_light
                            renderType: Text.NativeRendering
                        }
                        Text {
                            visible: !root.loading && root.accounts.length === 0
                            text: root.loadError !== "" ? root.loadError + " - rebuild to install keys" : "no keys yet - rebuild to install keys"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            color: theme.error
                            renderType: Text.NativeRendering
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Repeater {
                            model: root.accounts
                            delegate: Column {
                                required property var modelData
                                width: mainLayout.width
                                spacing: 3

                                // Label row: MG1 + copy button
                                Item {
                                    width: parent.width
                                    height: 14
                                    Text {
                                        text: modelData.label
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: root.used(modelData) ? theme.error : theme.fg
                                        renderType: Text.NativeRendering
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        visible: modelData.error !== ""
                                        text: modelData.error
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.error
                                        renderType: Text.NativeRendering
                                        anchors.left: parent.left
                                        anchors.leftMargin: 44
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.lastCopiedIdx === modelData.idx ? "copied!" : "copy key"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: copyMouse.containsMouse || root.lastCopiedIdx === modelData.idx ? theme.accent : theme.fg_light
                                        renderType: Text.NativeRendering
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea {
                                            id: copyMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            onClicked: root.copyKey(modelData.idx)
                                        }
                                    }
                                }

                                // Block progress bar (volume-popup style)
                                Row {
                                    id: barRow
                                    width: parent.width
                                    height: 5
                                    spacing: 1
                                    property bool used: root.used(modelData)
                                    property int filled: modelData.this_month < 0 ? 0 : Math.min(15, Math.round(modelData.this_month / root.capPer * 15))
                                    Repeater {
                                        model: 15
                                        delegate: Rectangle {
                                            width: (mainLayout.width - 14) / 15
                                            height: 5
                                            color: index < barRow.filled ? (barRow.used ? theme.error : theme.accent) : theme.bg_light
                                        }
                                    }
                                }

                                // Bottom row: this-month left, cap + reset right
                                Item {
                                    width: parent.width
                                    height: 13
                                    Text {
                                        text: root.fmt(modelData.this_month)
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        color: root.used(modelData) ? theme.error : theme.fg
                                        renderType: Text.NativeRendering
                                        anchors.left: parent.left
                                    }
                                    Text {
                                        text: "$" + root.capPer.toFixed(0) + " · " + root.resetLabel
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.fg_light
                                        renderType: Text.NativeRendering
                                        anchors.right: parent.right
                                    }
                                }
                                // Past month spend + most used model
                                Item {
                                    width: parent.width
                                    height: 12
                                    Text {
                                        text: root.prevMonthLabel + " " + root.fmt(modelData.prev_month)
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.fg_light
                                        renderType: Text.NativeRendering
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        visible: (modelData.top_model || "") !== ""
                                        text: modelData.top_model || ""
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        color: theme.secondary
                                        renderType: Text.NativeRendering
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, parent.width * 0.6)
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignRight
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
