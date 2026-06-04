import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string helperPath: homeDir + "/.config/quickshell/vm_popup/get_vm_status"
    property string thumbDir: "/tmp/vm_thumbs"
    property var vms: []
    property var qemuVms: []
    // Per-VM transitioning state (e.g. starting/stopping) so we can disable the action button
    property var pendingActions: ({
    })

    signal requestClose()

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function screenshotPathFor(vmx) {
        return thumbDir + "/" + vmx.replace(/[^a-zA-Z0-9]/g, "_") + ".png";
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

    function deleteVm(vmx) {
        if (root.pendingActions[vmx])
            return ;

        root.setPending(vmx, true);
        Quickshell.execDetached([root.helperPath, "delete", vmx]);
        actionCooldown.restart();
    }

    function startQemuVm(name) {
        var key = "qemu:" + name;
        if (root.pendingActions[key])
            return ;

        root.setPending(key, true);
        Quickshell.execDetached([root.helperPath, "qemu-start", name]);
        actionCooldown.restart();
    }

    function stopQemuVm(name) {
        var key = "qemu:" + name;
        if (root.pendingActions[key])
            return ;

        root.setPending(key, true);
        Quickshell.execDetached([root.helperPath, "qemu-stop", name]);
        actionCooldown.restart();
    }

    function openQemuVmGui(name) {
        Quickshell.execDetached(["virt-viewer", "-c", "qemu:///system", "--domain-name", name]);
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "10"]);
    }

    function deleteQemuVm(name) {
        var key = "qemu:" + name;
        if (root.pendingActions[key])
            return ;

        root.setPending(key, true);
        Quickshell.execDetached([root.helperPath, "qemu-delete", name]);
        actionCooldown.restart();
    }

    function openVmGui(vmx) {
        Quickshell.execDetached(["uwsm", "app", "--", "vmware", vmx]);
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "10"]);
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
                    root.qemuVms = data.qemu_vms || [];
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

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -360
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
                implicitWidth: 340
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
                    top: 4
                    left: win.animLeftMargin
                }

                // Slide-in + fade-in from the left
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: -360
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
                        to: -360
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
                    border.color: theme.c.accent
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

                        // Title Heading & Refresh Button
                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Virtual Machines"
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Row {
                                anchors.right: refreshLbl.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: " create vmw"
                                    color: "#7caea3"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    opacity: vmwMa.containsMouse ? 1 : 0.7

                                    MouseArea {
                                        id: vmwMa

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["vmware"]);
                                            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "10"]);
                                            win.closePopup();
                                        }
                                    }

                                }

                                Text {
                                    text: " create qemu"
                                    color: "#e78a4e"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    opacity: qemuMa.containsMouse ? 1 : 0.7

                                    MouseArea {
                                        id: qemuMa

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["virt-manager"]);
                                            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "9"]);
                                            win.closePopup();
                                        }
                                    }

                                }

                            }

                            Text {
                                id: refreshLbl

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "refresh"
                                color: theme.c.accent
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

                        // Header / Info Row
                        Row {
                            width: parent.width
                            spacing: 6
                            anchors.bottomMargin: 2

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰆧 " + root.vms.length + " vmware · " + root.qemuVms.length + " kvm/qemu"
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
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
                                property int localTick: 0

                                width: parent.width
                                height: Math.max(thumbBox.height, infoColumn.implicitHeight) + 4

                                // Local capture timer: only runs when this specific VM is active
                                Timer {
                                    interval: 10000
                                    repeat: true
                                    running: modelData.running
                                    triggeredOnStart: true
                                    onTriggered: {
                                        Quickshell.execDetached([root.helperPath, "screenshot", modelData.vmx, root.screenshotPathFor(modelData.vmx)]);
                                        localReloadTimer.restart();
                                    }
                                }

                                Timer {
                                    id: localReloadTimer

                                    interval: 1500
                                    repeat: false
                                    running: false
                                    onTriggered: vmRow.localTick++
                                }

                                Row {
                                    anchors.fill: parent
                                    spacing: 10

                                    // Thumbnail square with logo overlay
                                    Rectangle {
                                        id: thumbBox

                                        width: 120
                                        height: 88
                                        color: theme.c.bg_light
                                        radius: 0
                                        border.width: 1
                                        border.color: modelData.running ? theme.c.accent : "#7c6f64"

                                        // Live screenshot when running
                                        Image {
                                            id: thumbImage

                                            property bool hasLoaded: false

                                            anchors.fill: parent
                                            source: "file://" + root.screenshotPathFor(modelData.vmx) + "?t=" + vmRow.localTick
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            visible: hasLoaded && status !== Image.Error
                                            smooth: false
                                            onStatusChanged: {
                                                if (status === Image.Ready)
                                                    hasLoaded = true;

                                            }
                                        }

                                        // Placeholder when no screenshot yet
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !thumbImage.hasLoaded || thumbImage.status === Image.Error
                                            text: modelData.icon
                                            color: "#7c6f64"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 36
                                            renderType: Text.NativeRendering
                                        }

                                        // OS logo overlay (bottom-left, always shown on top of screenshot)
                                        Rectangle {
                                            width: 18
                                            height: 18
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            color: "#cc1d2021"
                                            radius: 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 12
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
                                        id: infoColumn

                                        width: parent.width - thumbBox.width - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        // Title
                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: theme.c.accent
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
                                                text: modelData.running ? "● running (" + modelData.cpu_usage.toFixed(1) + "% cpu)" : "○ stopped"
                                                color: modelData.running ? theme.c.accent : "#7c6f64"
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
                                                color: theme.c.accent
                                                opacity: 0.7
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Snapshots row
                                        Row {
                                            width: parent.width
                                            visible: modelData.snapshots && modelData.snapshots.count > 0

                                            Text {
                                                text: "  snapshots: " + modelData.snapshots.count + " (" + modelData.snapshots.last_time_ago + ")"
                                                color: "#a89984"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Shared Folders row
                                        Row {
                                            width: parent.width
                                            visible: modelData.shared_folders && modelData.shared_folders.length > 0

                                            Text {
                                                text: " : " + modelData.shared_folders.map(function(f) {
                                                    return f.guest_name + " ➜ " + f.host_path;
                                                }).join(", ")
                                                color: "#a89984"
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
                                                spacing: 12

                                                Text {
                                                    id: actionLbl

                                                    text: {
                                                        if (vmRow.isPending)
                                                            return "...";

                                                        if (modelData.running)
                                                            return " stop";

                                                        return " start";
                                                    }
                                                    color: modelData.running ? "#ea6962" : theme.c.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: actionMa.containsMouse ? 1 : 0.7

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

                                                Text {
                                                    id: openLbl

                                                    text: " open"
                                                    color: theme.c.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: openMa.containsMouse ? 1 : 0.7

                                                    MouseArea {
                                                        id: openMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openVmGui(modelData.vmx)
                                                    }

                                                }

                                                Text {
                                                    id: deleteLbl

                                                    text: " delete"
                                                    color: "#ea6962"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: deleteMa.containsMouse ? 1 : 0.7

                                                    MouseArea {
                                                        id: deleteMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !vmRow.isPending
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.deleteVm(modelData.vmx)
                                                    }

                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        // Dotted separator between vmware and qemu/libvirt sections
                        Text {
                            visible: root.vms.length > 0 || root.qemuVms.length > 0
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·"
                            color: "#7c6f64"
                            opacity: 0.6
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            renderType: Text.NativeRendering
                        }

                        // Qemu / libvirt empty state
                        Text {
                            visible: root.qemuVms.length === 0
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "0 kvm/qemu vms"
                            color: "#7c6f64"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                        }

                        // Qemu / libvirt VM list
                        Repeater {
                            model: root.qemuVms

                            delegate: Item {
                                id: qemuRow

                                required property var modelData
                                required property int index
                                property string pendingKey: "qemu:" + modelData.name
                                property bool isPending: root.pendingActions[pendingKey] === true
                                property int localTick: 0

                                width: parent.width
                                height: Math.max(qemuThumbBox.height, qemuInfoColumn.implicitHeight) + 4

                                // Local capture timer: only runs when this specific VM is active
                                Timer {
                                    interval: 10000
                                    repeat: true
                                    running: modelData.running
                                    triggeredOnStart: true
                                    onTriggered: {
                                        Quickshell.execDetached([root.helperPath, "screenshot", modelData.name, root.screenshotPathFor(modelData.name)]);
                                        qemuLocalReloadTimer.restart();
                                    }
                                }

                                Timer {
                                    id: qemuLocalReloadTimer

                                    interval: 1500
                                    repeat: false
                                    running: false
                                    onTriggered: qemuRow.localTick++
                                }

                                Row {
                                    anchors.fill: parent
                                    spacing: 10

                                    // Thumbnail square with logo overlay
                                    Rectangle {
                                        id: qemuThumbBox

                                        width: 120
                                        height: 88
                                        color: theme.c.bg_light
                                        radius: 0
                                        border.width: 1
                                        border.color: modelData.running ? theme.c.accent : "#7c6f64"

                                        // Live screenshot when running
                                        Image {
                                            id: qemuThumbImage

                                            property bool hasLoaded: false

                                            anchors.fill: parent
                                            source: "file://" + root.screenshotPathFor(modelData.name) + "?t=" + qemuRow.localTick
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            visible: hasLoaded && status !== Image.Error
                                            smooth: false
                                            onStatusChanged: {
                                                if (status === Image.Ready)
                                                    hasLoaded = true;

                                            }
                                        }

                                        // Placeholder when no screenshot yet
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !qemuThumbImage.hasLoaded || qemuThumbImage.status === Image.Error
                                            text: modelData.icon
                                            color: "#7c6f64"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 36
                                            renderType: Text.NativeRendering
                                        }

                                        // OS logo overlay (bottom-left, always shown on top)
                                        Rectangle {
                                            width: 18
                                            height: 18
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            color: "#cc1d2021"
                                            radius: 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 12
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Click opens VM GUI
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openQemuVmGui(modelData.name)
                                        }

                                    }

                                    // Right-side info
                                    Column {
                                        id: qemuInfoColumn

                                        width: parent.width - qemuThumbBox.width - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        // Title
                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: theme.c.accent
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
                                                text: modelData.running ? "● running (" + modelData.cpu_usage.toFixed(1) + "% cpu)" : "○ " + modelData.state
                                                color: modelData.running ? theme.c.accent : "#7c6f64"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "libvirt"
                                                color: "#7c6f64"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Resources row
                                        Row {
                                            width: parent.width
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: " " + root.formatRam(modelData.ram_mb) + " ·  " + modelData.cpus + "c · 󰋊 " + root.formatStorage(modelData.storage_bytes)
                                                color: theme.c.accent
                                                opacity: 0.7
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                        }

                                        // Connection URI row
                                        Row {
                                            width: parent.width

                                            Text {
                                                text: "󰌷 uri: qemu:///system"
                                                color: "#a89984"
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
                                                spacing: 12

                                                Text {
                                                    id: qemuActionLbl

                                                    text: {
                                                        if (qemuRow.isPending)
                                                            return "...";

                                                        if (modelData.running)
                                                            return " stop";

                                                        return " start";
                                                    }
                                                    color: modelData.running ? "#ea6962" : theme.c.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: qemuActionMa.containsMouse ? 1 : 0.7

                                                    MouseArea {
                                                        id: qemuActionMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !qemuRow.isPending
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.running)
                                                                root.stopQemuVm(modelData.name);
                                                            else
                                                                root.startQemuVm(modelData.name);
                                                        }
                                                    }

                                                }

                                                Text {
                                                    id: qemuOpenLbl

                                                    text: " open"
                                                    color: theme.c.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: qemuOpenMa.containsMouse ? 1 : 0.7

                                                    MouseArea {
                                                        id: qemuOpenMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openQemuVmGui(modelData.name)
                                                    }

                                                }

                                                Text {
                                                    id: qemuDeleteLbl

                                                    text: " delete"
                                                    color: "#ea6962"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering
                                                    opacity: qemuDeleteMa.containsMouse ? 1 : 0.7

                                                    MouseArea {
                                                        id: qemuDeleteMa

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !qemuRow.isPending
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.deleteQemuVm(modelData.name)
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
