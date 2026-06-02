import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string helperPath: "/home/parazeeknova/doty/.config/quickshell/vm_popup/get_vm_status"
    property string thumbDir: "/tmp/vm_thumbs"
    property var vms: []
    // Per-VM transitioning state (e.g. starting/stopping) so we can disable the action button
    property var pendingActions: ({
    })
    // Bumped after each capture cycle to force Image reload
    property int thumbTick: 0

    signal requestClose()

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function screenshotPathFor(vmx) {
        return thumbDir + "/" + vmx.replace(/[^a-zA-Z0-9]/g, "_") + ".png";
    }

    function captureAllScreens() {
        for (var i = 0; i < root.vms.length; i++) {
            var vm = root.vms[i];
            if (vm.running)
                Quickshell.execDetached([root.helperPath, "screenshot", vm.vmx, screenshotPathFor(vm.vmx)]);

        }
    }

    function setPending(vmx, on) {
        var p = root.pendingActions;
        if (on)
            p[vmx] = true;
        else
            delete p[vmx];
        root.pendingActions = p;
    }

    function startVm(vmx) {
        if (root.pendingActions[vmx])
            return ;

        root.setPending(vmx, true);
        Quickshell.execDetached([root.helperPath, "start", vmx]);
        actionCooldown.restart();
    }

    function stopVm(vmx) {
        if (root.pendingActions[vmx])
            return ;

        root.setPending(vmx, true);
        Quickshell.execDetached([root.helperPath, "stop", vmx]);
        actionCooldown.restart();
    }

    function openVmGui(vmx) {
        Quickshell.execDetached(["vmware", vmx]);
    }

    function formatRam(mb) {
        if (mb >= 1024)
            return Math.round(mb / 1024) + "G";

        return mb + "M";
    }

    function formatStorage(bytes) {
        var gb = bytes / 1.07374e+09;
        if (gb >= 100)
            return Math.round(gb) + "G";

        return gb.toFixed(1) + "G";
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", thumbDir]);
        refresh();
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "vm_popup"
    }

    // Fetch the VM list
    Process {
        id: listProc

        command: [root.helperPath, "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.vms = data.vms || [];
                    // Clear any stale pending flags - the VM may have transitioned successfully
                    root.pendingActions = ({
                    });
                } catch (e) {
                    console.log("Failed to parse VM list: " + e);
                }
            }
        }

    }

    // Cooldown after start/stop before re-fetching
    Timer {
        id: actionCooldown

        interval: 2500
        repeat: false
        running: false
        onTriggered: root.refresh()
    }

    // Periodic poll while popup is open
    Timer {
        id: pollTimer

        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: {
            if (!listProc.running && Object.keys(root.pendingActions).length === 0)
                root.refresh();

        }
    }

    // Capture screenshots on an interval while the popup exists.
    // Quickshell exits when the popup is closed, so this only runs while open.
    Timer {
        id: captureTimer

        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.captureAllScreens();
            // Reload images a moment later to pick up the freshly written files
            reloadTrigger.restart();
        }
    }

    Timer {
        id: reloadTrigger

        interval: 1500
        repeat: false
        running: false
        onTriggered: root.thumbTick++
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
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20
                Component.onCompleted: introAnim.start()

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
                    top: 32
                    left: win.animLeftMargin
                }

                // Slide-in + fade-in from the left
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: -260
                        to: 32
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                }

                // Slide-out + fade-out to the left
                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: 32
                        to: -260
                        duration: 110
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 110
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
                    color: theme.popupBgColor
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
                        spacing: 6

                        // Header
                        Row {
                            width: parent.width
                            spacing: 6
                            anchors.bottomMargin: 2

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: " " + root.vms.length + " Virtual Machine" + (root.vms.length === 1 ? "" : "s")
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Item {
                                width: parent.width - 150
                                height: 1
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "refresh"
                                color: "#d5c4a1"
                                opacity: 0.7
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.opacity = 1
                                    onExited: parent.opacity = 0.7
                                    onClicked: root.refresh()
                                }

                            }

                        }

                        // Empty state
                        Text {
                            visible: root.vms.length === 0
                            text: "no vms found"
                            color: "#7c6f64"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            renderType: Text.NativeRendering
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // VM list
                        Repeater {
                            model: root.vms

                            delegate: Item {
                                id: vmRow

                                required property var modelData
                                required property int index
                                // Track pending action for this VM (so the button can be disabled)
                                property bool isPending: root.pendingActions[modelData.vmx] === true

                                width: parent.width
                                height: 56

                                Row {
                                    anchors.fill: parent
                                    spacing: 8

                                    // Thumbnail square with logo overlay
                                    Rectangle {
                                        id: thumbBox

                                        width: 56
                                        height: 56
                                        color: "#3c3836"
                                        radius: 0
                                        border.width: 1
                                        border.color: modelData.running ? "#a9b665" : "#7c6f64"

                                        // Live screenshot when running
                                        Image {
                                            id: thumbImage

                                            anchors.fill: parent
                                            source: modelData.running ? "file://" + root.screenshotPathFor(modelData.vmx) + "?t=" + root.thumbTick : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            visible: status === Image.Ready
                                            smooth: false
                                        }

                                        // Placeholder when no screenshot yet
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !thumbImage.visible
                                            text: modelData.icon
                                            color: "#7c6f64"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 22
                                            renderType: Text.NativeRendering
                                        }

                                        // OS logo overlay (bottom-left, always shown on top of screenshot)
                                        Rectangle {
                                            width: 16
                                            height: 16
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            color: "#cc1d2021"
                                            radius: 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 11
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Click on the thumbnail opens the VM in VMware
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openVmGui(modelData.vmx)
                                        }

                                    }

                                    // Right-side info
                                    Column {
                                        width: parent.width - 64
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        // Title
                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: "#ebdbb2"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            font.bold: true
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                        }

                                        // Status row
                                        Row {
                                            width: parent.width
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.running ? "● running" : "○ stopped"
                                                color: modelData.running ? "#a9b665" : "#7c6f64"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: modelData.encrypted
                                                text: " 󰌾 lock"
                                                color: "#e78a4e"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Item {
                                                width: 1
                                                height: 1
                                            }

                                        }

                                        // Resources row
                                        Row {
                                            width: parent.width
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: " " + root.formatRam(modelData.ram_mb) + " ·  " + modelData.cpus + "c · 󰋊 " + root.formatStorage(modelData.storage_bytes)
                                                color: "#d5c4a1"
                                                opacity: 0.7
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Action buttons
                                        Item {
                                            width: parent.width
                                            height: 18

                                            Row {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.topMargin: 6
                                                spacing: 4

                                                Rectangle {
                                                    id: actionBtn

                                                    width: actionLbl.implicitWidth + 10
                                                    height: 14
                                                    color: actionMa.containsMouse ? (modelData.running ? "#3c3836" : "#3c3836") : "transparent"
                                                    border.color: modelData.running ? "#ea6962" : "#a9b665"
                                                    border.width: 1
                                                    opacity: vmRow.isPending ? 0.5 : 1

                                                    Text {
                                                        id: actionLbl

                                                        anchors.centerIn: parent
                                                        text: {
                                                            if (vmRow.isPending)
                                                                return "...";

                                                            if (modelData.running)
                                                                return " stop";

                                                            return " start";
                                                        }
                                                        color: modelData.running ? "#ea6962" : "#a9b665"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering
                                                    }

                                                    MouseArea {
                                                        id: actionMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !vmRow.isPending
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.running)
                                                                root.stopVm(modelData.vmx);
                                                            else
                                                                root.startVm(modelData.vmx);
                                                        }
                                                    }

                                                }

                                                Rectangle {
                                                    id: openBtn

                                                    width: openLbl.implicitWidth + 10
                                                    height: 14
                                                    color: openMa.containsMouse ? "#3c3836" : "transparent"
                                                    border.color: "#7c6f64"
                                                    border.width: 1

                                                    Text {
                                                        id: openLbl

                                                        anchors.centerIn: parent
                                                        text: " open"
                                                        color: "#d5c4a1"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        renderType: Text.NativeRendering
                                                    }

                                                    MouseArea {
                                                        id: openMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openVmGui(modelData.vmx)
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

        }

    }

}
