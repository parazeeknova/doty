import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    signal requestClose

    readonly property string fontName: "FiraCode Nerd Font"

    Theme { id: theme }

    property var chatHistory: []
    property int selectedChatIndex: -1
    property string currentChatId: ""
    property var messages: []
    property string inputText: ""

    Component.onCompleted: {
        chatHistory = loadChatHistory()
        if (chatHistory.length > 0) {
            selectedChatIndex = 0
            currentChatId = chatHistory[0].id
            messages = loadMessages(currentChatId)
        }
    }

    function loadChatHistory() {
        var fileView = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "file://' + root.homeDir + '/.cache/quickshell/chat_sidebar/chats.json"; watchChanges: false }', root, "chatsFV"
        )
        if (fileView) {
            var t = fileView.text()
            if (t && t.trim().length > 0) {
                try { return JSON.parse(t) } catch (e) { return [] }
            }
        }
        return []
    }

    function loadMessages(chatId) {
        var fileView = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "file://' + root.homeDir + '/.cache/quickshell/chat_sidebar/' + chatId + '.json"; watchChanges: false }', root, "msgsFV"
        )
        if (fileView) {
            var t = fileView.text()
            if (t && t.trim().length > 0) {
                try { return JSON.parse(t) } catch (e) { return [] }
            }
        }
        return []
    }

    function writeFile(path, content) {
        var fileView = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "file://' + path + '" }', root, "writeFV"
        )
        if (fileView) fileView.write(content)
    }

    function saveChatHistory() { writeFile(root.homeDir + "/.cache/quickshell/chat_sidebar/chats.json", JSON.stringify(chatHistory)) }
    function saveMessages() { if (!currentChatId) return; writeFile(root.homeDir + "/.cache/quickshell/chat_sidebar/" + currentChatId + ".json", JSON.stringify(messages)) }

    function newChat() {
        var id = "chat_" + Date.now()
        chatHistory.unshift({ id: id, name: "New Chat", created: new Date().toISOString() })
        saveChatHistory()
        selectedChatIndex = 0
        currentChatId = id
        messages = []
    }

    function deleteChat(index) {
        if (index < 0 || index >= chatHistory.length) return
        var chatId = chatHistory[index].id
        chatHistory.splice(index, 1)
        saveChatHistory()
        if (chatHistory.length > 0) {
            selectedChatIndex = Math.min(index, chatHistory.length - 1)
            currentChatId = chatHistory[selectedChatIndex].id
            messages = loadMessages(currentChatId)
        } else {
            selectedChatIndex = -1
            currentChatId = ""
            messages = []
        }
    }

    function sendMessage() {
        if (inputText.trim().length === 0) return
        if (!currentChatId) newChat()
        messages.push({ role: "user", text: inputText.trim(), timestamp: new Date().toISOString() })
        inputText = ""
        saveMessages()
    }

    function formatTimestamp(isoStr) {
        if (!isoStr) return ""
        try {
            var d = new Date(isoStr)
            return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
        } catch (e) { return "" }
    }

    Rectangle {
        id: mainContainer
        anchors {
            left: parent.left
            leftMargin: 32
            top: parent.top
            topMargin: 40
            bottom: parent.bottom
            bottomMargin: 40
        }
        width: 900
        height: undefined
        color: theme.popupBgColor
        radius: 0

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // LEFT SIDEBAR
            Rectangle {
                id: sidebarPanel
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: theme.bg_dark
                radius: 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: theme.bg_dark
                        radius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: "Chats"
                                font.family: root.fontName
                                font.pointSize: 11
                                font.bold: true
                                color: theme.fg
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            Button {
                                text: "New"
                                font.family: root.fontName
                                font.pointSize: 8
                                background: Rectangle { color: theme.accent; radius: 0 }
                                contentItem: Text {
                                    text: "New"
                                    color: "#ffffff"
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.newChat()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.accent; opacity: 0.3 }

                    ComboBox {
                        id: chatDropdown
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 4
                        model: chatHistory
                        textRole: "name"
                        currentIndex: root.selectedChatIndex
                        font.family: root.fontName
                        font.pointSize: 8
                        background: Rectangle {
                            color: theme.bg
                            radius: 0
                            border.width: 1
                            border.color: theme.accent
                            opacity: chatDropdown.activeFocus ? 1 : 0.4
                            Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }
                        delegate: Item {
                            width: chatDropdown.width
                            height: 28
                            Text {
                                text: modelData.name || ("Chat " + (index + 1))
                                color: chatDropdown.highlightedIndex === index ? theme.accent : theme.fg
                                font.family: root.fontName
                                font.pointSize: 8
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                renderType: Text.NativeRendering
                                elide: Text.ElideRight
                                width: parent.width - 16
                            }
                        }
                        popup: Popup {
                            y: chatDropdown.height
                            width: chatDropdown.width
                            height: Math.min(chatDropdown.model.length * 28, 200)
                            padding: 0
                            modal: true
                            closePolicy: Popup.CloseOnPressOutsideParent
                            background: Rectangle { color: theme.bg_dark; radius: 0; border.width: 1; border.color: theme.accent; opacity: 0.6 }
                        }
                        onCurrentIndexChanged: {
                            if (index >= 0 && index < chatHistory.length) {
                                selectedChatIndex = index
                                currentChatId = chatHistory[index].id
                                messages = loadMessages(currentChatId)
                            }
                        }
                    }

                    Button {
                        text: "Delete Chat"
                        font.family: root.fontName
                        font.pointSize: 8
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 4
                        Layout.preferredHeight: 28
                        background: Rectangle { color: theme.error; opacity: 0.85; radius: 0 }
                        contentItem: Text {
                            text: "Delete Chat"
                            color: "#ffffff"
                            font.family: root.fontName
                            font.pointSize: 8
                            font.bold: true
                            renderType: Text.NativeRendering
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (selectedChatIndex >= 0) deleteChat(selectedChatIndex)
                        }
                    }

                    ListView {
                        id: chatList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: chatHistory
                        clip: true
                        spacing: 1
                        delegate: Item {
                            width: chatList.width
                            height: 36
                            Rectangle {
                                anchors.fill: parent
                                color: (index === root.selectedChatIndex) ? theme.accent : "transparent"
                                opacity: (index === root.selectedChatIndex) ? 0.15 : 1.0
                                radius: 0
                                Text {
                                    text: modelData.name || ("Chat " + (index + 1))
                                    color: (index === root.selectedChatIndex) ? theme.accent : theme.fg
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    renderType: Text.NativeRendering
                                    elide: Text.ElideRight
                                    width: parent.width - 24
                                }
                                Text {
                                    text: formatTimestamp(modelData.created)
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 6
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    renderType: Text.NativeRendering
                                    opacity: 0.6
                                    visible: index === root.selectedChatIndex
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        chatDropdown.currentIndex = index
                                        root.selectedChatIndex = index
                                        currentChatId = chatHistory[index].id
                                        messages = loadMessages(currentChatId)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // DIVIDER
            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.accent; opacity: 0.3 }

            // RIGHT CHAT PANEL
            Rectangle {
                id: chatPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.bg
                radius: 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: theme.bg_dark
                        radius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: currentChatId ? (chatHistory[selectedChatIndex] ? chatHistory[selectedChatIndex].name : "Chat") : "No Chat"
                                font.family: root.fontName
                                font.pointSize: 9
                                font.bold: true
                                color: theme.fg
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.messages.length + " msgs"
                                font.family: root.fontName
                                font.pointSize: 7
                                color: theme.secondary
                                renderType: Text.NativeRendering
                                visible: root.messages.length > 0
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.accent; opacity: 0.2 }

                    ListView {
                        id: messagesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.messages
                        spacing: 4
                        clip: true
                        delegate: Item {
                            width: messagesList.width
                            height: messageItem.implicitHeight + 12

                            Rectangle {
                                id: messageItem
                                width: parent.width - 48
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: (model.role === "user") ? theme.bg_dark : theme.bg_light
                                radius: 0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    spacing: 8

                                    Text {
                                        text: (model.role === "user") ? "You" : "AI"
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        font.bold: true
                                        color: (model.role === "user") ? theme.accent : theme.tertiary
                                        renderType: Text.NativeRendering
                                        Layout.preferredWidth: 30
                                        verticalAlignment: Text.AlignTop
                                    }

                                    Text {
                                        text: model.text || ""
                                        color: theme.fg
                                        font.family: root.fontName
                                        font.pointSize: 8
                                        renderType: Text.NativeRendering
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        text: formatTimestamp(model.timestamp)
                                        font.family: root.fontName
                                        font.pointSize: 6
                                        color: theme.secondary
                                        renderType: Text.NativeRendering
                                        opacity: 0.5
                                        verticalAlignment: Text.AlignTop
                                        Layout.preferredWidth: 40
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.accent; opacity: 0.2 }

                    Rectangle {
                        id: inputArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: theme.bg_dark
                        radius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            TextField {
                                id: messageInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: root.inputText
                                placeholderText: "Type a command or message..."
                                font.family: root.fontName
                                font.pointSize: 8
                                color: theme.fg
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                onAccepted: root.sendMessage()

                                background: Rectangle {
                                    color: theme.bg
                                    radius: 0
                                    border.width: 1
                                    border.color: theme.accent
                                    opacity: messageInput.activeFocus ? 1 : 0.4
                                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }

                            Button {
                                text: "Send"
                                font.family: root.fontName
                                font.pointSize: 8
                                Layout.preferredWidth: 70
                                Layout.fillHeight: true
                                background: Rectangle { color: theme.accent; radius: 0 }
                                contentItem: Text {
                                    text: "Send"
                                    color: "#ffffff"
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.sendMessage()
                            }
                        }
                    }
                }
            }
        }
    }
}
