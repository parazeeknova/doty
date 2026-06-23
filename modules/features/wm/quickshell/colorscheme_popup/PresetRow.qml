import QtQuick
import Quickshell

Rectangle {
    id: presetRow

    property string rowName: ""
    property bool rowActive: false
    property bool rowFocused: false
    property var dotColors: []
    signal triggered

    height: 14
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0.0
            color: (presetRow.rowActive || presetRow.rowFocused || rowMouse.containsMouse) ? ((presetRow.dotColors && presetRow.dotColors.length > 1) ? presetRow.getTranslucentColor(presetRow.dotColors[1], 0.7) : presetRow.getTranslucentColor(theme.bg_light, 0.7)) : ((presetRow.dotColors && presetRow.dotColors.length > 0) ? presetRow.getTranslucentColor(presetRow.dotColors[0], 0.25) : "transparent")
        }
        GradientStop {
            position: 1.0
            color: (presetRow.rowActive || presetRow.rowFocused || rowMouse.containsMouse) ? ((presetRow.dotColors && presetRow.dotColors.length > 3) ? presetRow.getTranslucentColor(presetRow.dotColors[3], 0.35) : presetRow.getTranslucentColor(theme.accent, 0.35)) : ((presetRow.dotColors && presetRow.dotColors.length > 1) ? presetRow.getTranslucentColor(presetRow.dotColors[1], 0.1) : "transparent")
        }
    }

    function getTranslucentColor(colorStr, opacity) {
        var c = Qt.color(colorStr);
        return Qt.rgba(c.r, c.g, c.b, opacity);
    }

    function isLightTheme(colorStr) {
        var c = Qt.color(colorStr);
        var luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return luminance > 0.5;
    }

    function getTextColor(isActiveOrHovered) {
        var isLight = (presetRow.dotColors && presetRow.dotColors.length > 0 && presetRow.isLightTheme(presetRow.dotColors[0]));
        if (isActiveOrHovered) {
            if (isLight)
                return theme.accent;
            return (presetRow.dotColors && presetRow.dotColors.length > 3) ? presetRow.dotColors[3] : theme.accent;
        } else {
            if (isLight)
                return theme.fg_light;
            return (presetRow.dotColors && presetRow.dotColors.length > 2) ? presetRow.dotColors[2] : theme.fg_light;
        }
    }

    function getIcon(name) {
        var n = name.toLowerCase();
        if (n.indexOf("auto") !== -1)
            return "󰸉";
        if (n.indexOf("catppuccin") !== -1)
            return "󰄛";
        if (n.indexOf("dracula") !== -1)
            return "󰊠";
        if (n.indexOf("everforest") !== -1)
            return "󰐅";
        if (n.indexOf("gruvbox") !== -1)
            return "󰛊";
        if (n.indexOf("kanagawa") !== -1)
            return "󰈉";
        if (n.indexOf("monokai") !== -1)
            return "󰅩";
        if (n.indexOf("nord") !== -1)
            return "󰖘";
        if (n.indexOf("one-dark") !== -1 || n.indexOf("onedark") !== -1)
            return "󰘦";
        if (n.indexOf("rose") !== -1 || n.indexOf("pine") !== -1)
            return "󰄗";
        if (n.indexOf("solarized") !== -1)
            return "󰖨";
        if (n.indexOf("tokyonight") !== -1 || n.indexOf("tokyo") !== -1)
            return "󰖔";
        if (n.indexOf("ayu") !== -1)
            return "󰆧";
        return "󰏘";
    }

    // Accent bar on the left edge based on colorscheme's accent color
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: (presetRow.dotColors && presetRow.dotColors.length > 3) ? presetRow.dotColors[3] : theme.accent
        visible: presetRow.rowActive || presetRow.rowFocused || rowMouse.containsMouse
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: presetRow.triggered()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6

        Text {
            id: iconText
            text: presetRow.getIcon(presetRow.rowName)
            color: presetRow.getTextColor(presetRow.rowActive || presetRow.rowFocused || rowMouse.containsMouse)
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 8
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
        }

        Text {
            text: {
                var nameText = presetRow.rowName;
                if (presetRow.dotColors && presetRow.dotColors.length > 0 && presetRow.isLightTheme(presetRow.dotColors[0])) {
                    nameText += " 󰖨";
                }
                return presetRow.rowActive ? (nameText + " - active") : nameText;
            }
            color: presetRow.getTextColor(presetRow.rowActive)
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 8
            font.bold: presetRow.rowActive
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: iconText.right
            anchors.leftMargin: 4
        }

        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            visible: presetRow.rowActive || presetRow.rowFocused || rowMouse.containsMouse

            Repeater {
                model: presetRow.dotColors

                delegate: Rectangle {
                    width: 8
                    height: 8
                    color: modelData
                }
            }
        }
    }
}
