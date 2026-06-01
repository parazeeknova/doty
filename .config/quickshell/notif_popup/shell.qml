import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property var activeNotifs: []
    property var historyNotifs: []
    property bool historyExpanded: false
    property bool btEnabled: false
    property bool wifiEnabled: false
    property bool audioMuted: false
    property string hourStr: ""
    property string minStr: ""
    property string secStr: ""
    property string ampmStr: ""
    property string uptimeStr: ""
    property int calendarMonthOffset: 0
    // Track expanded notification IDs
    property var expandedNotifIds: ({
    })

    signal requestClose()

    function getCalendarDays(offset) {
        var date = new Date();
        date.setMonth(date.getMonth() + offset);
        var year = date.getFullYear();
        var month = date.getMonth();
        var firstDay = new Date(year, month, 1);
        var startDayOfWeek = firstDay.getDay();
        var numDays = new Date(year, month + 1, 0).getDate();
        var numDaysPrev = new Date(year, month, 0).getDate();
        var days = [];
        for (var i = startDayOfWeek - 1; i >= 0; i--) {
            days.push({
                "day": numDaysPrev - i,
                "isCurrentMonth": false,
                "isToday": false
            });
        }
        var todayDate = new Date();
        for (var d = 1; d <= numDays; d++) {
            var isToday = (todayDate.getDate() === d && todayDate.getMonth() === month && todayDate.getFullYear() === year);
            days.push({
                "day": d,
                "isCurrentMonth": true,
                "isToday": isToday
            });
        }
        var remaining = 42 - days.length;
        for (var n = 1; n <= remaining; n++) {
            days.push({
                "day": n,
                "isCurrentMonth": false,
                "isToday": false
            });
        }
        return days;
    }

    function triggerRefresh() {
        checkNotifsProc.running = false;
        checkNotifsProc.running = true;
    }

    Component.onCompleted: {
        triggerRefresh();
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "notif_popup"
    }

    Timer {
        id: clockTimer

        interval: 500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date();
            var hours = date.getHours();
            var minutes = date.getMinutes();
            var seconds = date.getSeconds();
            var ampm = hours >= 12 ? 'PM' : 'AM';
            hours = hours % 12;
            hours = hours ? hours : 12;
            root.hourStr = hours < 10 ? '0' + hours : String(hours);
            root.minStr = minutes < 10 ? '0' + minutes : String(minutes);
            root.secStr = seconds < 10 ? '0' + seconds : String(seconds);
            root.ampmStr = ampm;
        }
    }

    Timer {
        id: periodicRefreshTimer

        interval: 600000 // 10 minutes in ms
        repeat: true
        running: true
        onTriggered: {
            root.triggerRefresh();
        }
    }

    // Process to fetch notification lists
    Process {
        id: checkNotifsProc

        command: ["/home/parazeeknova/doty/.config/quickshell/notif_popup/get_notif_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.activeNotifs = data.active || [];
                    root.historyNotifs = data.history || [];
                    root.btEnabled = data.bt_enabled || false;
                    root.wifiEnabled = data.wifi_enabled || false;
                    root.audioMuted = data.audio_muted || false;
                    root.uptimeStr = data.uptime || "";
                } catch (e) {
                    console.log("Failed to parse notifications: " + e);
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
                Component.onCompleted: introAnim.start()
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    left: true
                }

                // Center vertically on the left screen edge
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

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: "#801d2021"
                    border.width: 1
                    border.color: "#d5c4a1"
                    radius: 0
                    antialiasing: false
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    Column {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 10

                        // --- SECTION 0: CLOCK & CALENDAR ---
                        Row {
                            width: parent.width
                            spacing: 10

                            // Left side: Concise Calendar & Nav Buttons wrapper
                            Item {
                                id: calendarWrapper

                                width: 155
                                height: calCol.implicitHeight

                                Column {
                                    id: calCol

                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 145
                                    spacing: 4

                                    // Calendar Month/Year Header
                                    Text {
                                        text: {
                                            var date = new Date();
                                            date.setMonth(date.getMonth() + root.calendarMonthOffset);
                                            var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                                            return months[date.getMonth()] + " " + date.getFullYear();
                                        }
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.8
                                        renderType: Text.NativeRendering
                                    }

                                    // Days of week header
                                    Row {
                                        width: parent.width

                                        Repeater {
                                            model: ["S", "M", "T", "W", "T", "F", "S"]

                                            delegate: Item {
                                                width: parent.width / 7
                                                height: 12

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: "#d5c4a1"
                                                    opacity: 0.5
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                    renderType: Text.NativeRendering
                                                }

                                            }

                                        }

                                    }

                                    // Days Grid
                                    Grid {
                                        width: parent.width
                                        columns: 7
                                        rowSpacing: 3
                                        columnSpacing: 0

                                        Repeater {
                                            model: root.getCalendarDays(root.calendarMonthOffset)

                                            delegate: Rectangle {
                                                width: parent.width / 7
                                                height: 13
                                                color: modelData.isToday ? "#d5c4a1" : "transparent"
                                                border.width: 0
                                                radius: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(modelData.day)
                                                    color: modelData.isToday ? "#1d2021" : "#d5c4a1"
                                                    opacity: modelData.isToday ? 1 : (modelData.isCurrentMonth ? 0.85 : 0.25)
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 7
                                                    font.bold: modelData.isToday
                                                    renderType: Text.NativeRendering
                                                }

                                            }

                                        }

                                    }

                                }

                                // Previous Month Button (Top Right)
                                Text {
                                    id: prevMonthBtn

                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    text: ""
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                    opacity: 0.6
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.calendarMonthOffset -= 1
                                    }

                                }

                                // Next Month Button (Bottom Right)
                                Text {
                                    id: nextMonthBtn

                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.bottomMargin: 2
                                    text: ""
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                    opacity: 0.6
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.calendarMonthOffset += 1
                                    }

                                }

                            }

                            // Right side: Vertical Time
                            Column {
                                width: parent.width - 165
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: root.hourStr
                                    color: "#ebdbb2"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 22
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: root.minStr
                                    color: "#ebdbb2"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 22
                                    font.bold: false
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    Text {
                                        text: root.secStr
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: root.ampmStr
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: false
                                        renderType: Text.NativeRendering
                                    }

                                }

                                Item {
                                    width: 1
                                    height: 6
                                }

                                Text {
                                    text: "X"
                                    color: "#d5c4a1"
                                    opacity: 0.4
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Item {
                                    width: 1
                                    height: 6
                                }

                                Text {
                                    text: root.uptimeStr.replace("UP ", "")
                                    color: "#d5c4a1"
                                    opacity: 0.75
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: false
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                        }

                        // --- SECTION 1 & 2: NOTIFICATIONS HEADER & LIST ---
                        Column {
                            width: parent.width
                            spacing: 4

                            // Header & Actions
                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Notifications"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 10
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: clearAllBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Clear All"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: false
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: clearAllBtn.color = "#ebdbb2"
                                        onExited: clearAllBtn.color = "#d5c4a1"
                                        onClicked: {
                                            Quickshell.execDetached(["makoctl", "dismiss", "-a"]);
                                            root.activeNotifs = [];
                                            root.triggerRefresh();
                                        }
                                    }

                                }

                            }

                            // Active Notifications list
                            Column {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: "Active"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                    opacity: 0.6
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "No active notifications"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    opacity: 0.4
                                    renderType: Text.NativeRendering
                                    visible: root.activeNotifs.length === 0
                                }

                                Repeater {
                                    model: root.activeNotifs

                                    delegate: Rectangle {
                                        width: parent.width
                                        // Size dynamically to Column child layout
                                        height: activeBoxCol.implicitHeight + 10
                                        color: "#282828"
                                        border.width: 1
                                        border.color: modelData.urgency === "critical" ? "#ea6962" : "#3c3836"

                                        Column {
                                            id: activeBoxCol

                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 5
                                            spacing: 4

                                            Row {
                                                width: parent.width
                                                spacing: 8

                                                // App Icon
                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    color: "transparent"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: modelData.app_icon !== ""

                                                    Image {
                                                        anchors.fill: parent
                                                        source: modelData.app_icon.startsWith("/") ? ("file://" + modelData.app_icon) : ("image://icon/" + modelData.app_icon)
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                    }

                                                }

                                                Column {
                                                    width: parent.width - (modelData.app_icon !== "" ? 28 : 0)
                                                    spacing: 2
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Item {
                                                        width: parent.width
                                                        height: 12

                                                        Text {
                                                            text: modelData.summary
                                                            color: "#d5c4a1"
                                                            font.family: "FiraCode Nerd Font"
                                                            font.pixelSize: 8
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                            anchors.left: parent.left
                                                            anchors.right: dismissBtn.left
                                                            anchors.rightMargin: 5
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            renderType: Text.NativeRendering
                                                        }

                                                        Text {
                                                            id: dismissBtn

                                                            anchors.right: parent.right
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: "dismiss"
                                                            color: "#d5c4a1"
                                                            font.family: "FiraCode Nerd Font"
                                                            font.pixelSize: 8
                                                            font.bold: true
                                                            renderType: Text.NativeRendering

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                onEntered: dismissBtn.color = "#ebdbb2"
                                                                onExited: dismissBtn.color = "#d5c4a1"
                                                                onClicked: {
                                                                    Quickshell.execDetached(["makoctl", "dismiss", "-n", String(modelData.id)]);
                                                                    root.triggerRefresh();
                                                                }
                                                            }

                                                        }

                                                    }

                                                }

                                            }

                                            // Description Box
                                            Column {
                                                width: parent.width
                                                spacing: 2

                                                // Text body element
                                                Text {
                                                    id: descText

                                                    text: modelData.body
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    wrapMode: Text.Wrap
                                                    width: parent.width
                                                    // 1 line limit when collapsed, unlimited when expanded
                                                    elide: root.expandedNotifIds[modelData.id] ? Text.ElideNone : Text.ElideRight
                                                    maximumLineCount: root.expandedNotifIds[modelData.id] ? 99 : 1
                                                    renderType: Text.NativeRendering
                                                }

                                                // Expand control row (shown as secondary line when collapsed, or bottom control when expanded)
                                                Item {
                                                    width: parent.width
                                                    height: 10
                                                    visible: modelData.body.length > 50 || modelData.body.includes("\n")

                                                    Text {
                                                        id: showMoreBtn

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.expandedNotifIds[modelData.id] ? "show less" : "show more"
                                                        color: "#d5c4a1"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                        font.bold: true
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                var copy = Object.assign({
                                                                }, root.expandedNotifIds);
                                                                copy[modelData.id] = !copy[modelData.id];
                                                                root.expandedNotifIds = copy;
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

                        // --- SECTION 3: HISTORY ---
                        Column {
                            width: parent.width
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 14

                                Row {
                                    id: historyTitleRow

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: root.historyExpanded ? "" : ""
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.6
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "History"
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.6
                                        renderType: Text.NativeRendering
                                    }

                                }

                                MouseArea {
                                    anchors.fill: historyTitleRow
                                    onClicked: {
                                        root.historyExpanded = !root.historyExpanded;
                                    }
                                }

                                Text {
                                    id: restoreBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Restore Last"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    visible: root.historyNotifs.length > 0

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: restoreBtn.color = "#ebdbb2"
                                        onExited: restoreBtn.color = "#d5c4a1"
                                        onClicked: {
                                            Quickshell.execDetached(["makoctl", "restore"]);
                                            root.triggerRefresh();
                                        }
                                    }

                                }

                            }

                            Column {
                                width: parent.width
                                spacing: 6
                                visible: root.historyExpanded

                                Text {
                                    text: "No history"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    opacity: 0.4
                                    renderType: Text.NativeRendering
                                    visible: root.historyNotifs.length === 0
                                }

                                Repeater {
                                    model: root.historyNotifs

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: histBoxCol.implicitHeight + 10
                                        color: "#1d2021"
                                        border.width: 1
                                        border.color: "#3c3836"

                                        Column {
                                            id: histBoxCol

                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 5
                                            spacing: 4

                                            Row {
                                                width: parent.width
                                                spacing: 8

                                                // App Icon
                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    color: "transparent"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: modelData.app_icon !== ""

                                                    Image {
                                                        anchors.fill: parent
                                                        source: modelData.app_icon.startsWith("/") ? ("file://" + modelData.app_icon) : ("image://icon/" + modelData.app_icon)
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                    }

                                                }

                                                Column {
                                                    width: parent.width - (modelData.app_icon !== "" ? 28 : 0)
                                                    spacing: 2
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        text: modelData.summary
                                                        color: "#d5c4a1"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                        renderType: Text.NativeRendering
                                                    }

                                                }

                                            }

                                            // Description Box
                                            Column {
                                                width: parent.width
                                                spacing: 2

                                                Text {
                                                    id: histDescText

                                                    text: modelData.body
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    wrapMode: Text.Wrap
                                                    width: parent.width
                                                    elide: root.expandedNotifIds[modelData.id + "_hist"] ? Text.ElideNone : Text.ElideRight
                                                    maximumLineCount: root.expandedNotifIds[modelData.id + "_hist"] ? 99 : 1
                                                    renderType: Text.NativeRendering
                                                }

                                                Item {
                                                    width: parent.width
                                                    height: 10
                                                    visible: modelData.body.length > 60 || modelData.body.includes("\n")

                                                    Text {
                                                        id: histShowMoreBtn

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.expandedNotifIds[modelData.id + "_hist"] ? "show less" : "show more"
                                                        color: "#d5c4a1"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                        font.bold: true
                                                        renderType: Text.NativeRendering

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                var copy = Object.assign({
                                                                }, root.expandedNotifIds);
                                                                copy[modelData.id + "_hist"] = !copy[modelData.id + "_hist"];
                                                                root.expandedNotifIds = copy;
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

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                        }

                        Row {
                            width: parent.width

                            // Volume Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnVol

                                    anchors.centerIn: parent
                                    text: root.audioMuted ? "󰝟" : "󰕾"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnVol.color = "#ebdbb2"
                                    onExited: btnVol.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "volume_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // Network Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnNet

                                    anchors.centerIn: parent
                                    text: root.wifiEnabled ? "󰖩" : "󰖪"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnNet.color = "#ebdbb2"
                                    onExited: btnNet.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "network_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // Bluetooth Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnBt

                                    anchors.centerIn: parent
                                    text: root.btEnabled ? "󰂯" : "󰂲"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnBt.color = "#ebdbb2"
                                    onExited: btnBt.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "bluetooth_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // Brightness Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnBright

                                    anchors.centerIn: parent
                                    text: "󰃠"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnBright.color = "#ebdbb2"
                                    onExited: btnBright.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "brightness_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // Battery Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnBat

                                    anchors.centerIn: parent
                                    text: "󰁹"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnBat.color = "#ebdbb2"
                                    onExited: btnBat.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "battery_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // System Monitor Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnSysmon

                                    anchors.centerIn: parent
                                    text: "󰣖"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnSysmon.color = "#ebdbb2"
                                    onExited: btnSysmon.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "sysmon_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                        }

                        Row {
                            width: parent.width

                            // Podman Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnPodman

                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnPodman.color = "#ebdbb2"
                                    onExited: btnPodman.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "podman_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // Emoji Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnEmoji

                                    anchors.centerIn: parent
                                    text: "󰞅"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnEmoji.color = "#ebdbb2"
                                    onExited: btnEmoji.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "emoji_popup"]);
                                        win.closePopup();
                                    }
                                }

                            }

                            // OCR Button
                            Item {
                                width: parent.width / 6
                                height: 14

                                Text {
                                    id: btnOcr

                                    anchors.centerIn: parent
                                    text: "󰚢"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnOcr.color = "#ebdbb2"
                                    onExited: btnOcr.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "ocr_popup"]);
                                        win.closePopup();
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
