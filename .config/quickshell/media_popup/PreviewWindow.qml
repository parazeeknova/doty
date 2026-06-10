import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: previewWin

    property var rootObj
    property var winObj
    property var themeObj

    screen: winObj.screen
    color: "transparent"
    exclusionMode: PanelWindow.ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        left: true
    }

    margins {
        top: 4
        left: winObj.animOffsetX + 240 + 8
    }

    implicitWidth: {
        if (rootObj.previewAsset) {
            var w = rootObj.previewAsset.width || 300;
            var h = rootObj.previewAsset.height || 300;
            if (w <= 0 || h <= 0) return 300;
            var maxDim = 400;
            var minDim = 150;
            if (w > h) {
                return Math.max(minDim, Math.min(w, maxDim));
            } else {
                return Math.max(minDim, Math.min(w * (maxDim / h), maxDim));
            }
        } else if (rootObj.previewOcrText !== "") {
            return 300;
        }
        return 200;
    }
    implicitHeight: {
        if (rootObj.previewAsset) {
            var w = rootObj.previewAsset.width || 300;
            var h = rootObj.previewAsset.height || 300;
            if (w <= 0 || h <= 0) return 300;
            var maxDim = 400;
            var minDim = 150;
            if (h > w) {
                return Math.max(minDim, Math.min(h, maxDim));
            } else {
                return Math.max(minDim, Math.min(h * (maxDim / w), maxDim));
            }
        } else if (rootObj.previewOcrText !== "") {
            return Math.max(120, Math.min(250, ocrTextPreview.implicitHeight + 16));
        }
        return 200;
    }

    visible: (rootObj.previewAsset !== null || rootObj.previewOcrText !== "") && !winObj.isClosing
    onVisibleChanged: {
        if (!visible) {
            previewFlickable.zoomScale = 1.0;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: themeObj.popupBgColor
        border.width: 1
        border.color: themeObj.accent
        radius: 0
        antialiasing: false

        MouseArea {
            anchors.fill: parent
            onClicked: rootObj.closePreview()
        }

        // Image and Video Flickable container (for drag & zoom)
        Flickable {
            id: previewFlickable
            anchors.fill: parent
            contentWidth: Math.max(width, mediaContainer.width)
            contentHeight: Math.max(height, mediaContainer.height)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: rootObj.previewAsset !== null

            property real zoomScale: 1.0

            Item {
                id: mediaContainer
                width: previewFlickable.width * previewFlickable.zoomScale
                height: previewFlickable.height * previewFlickable.zoomScale

                // Image Preview (Screenshots)
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: rootObj.previewAsset && rootObj.previewAsset.type === "screenshot" && !rootObj.previewAsset.deleted ? "file://" + rootObj.previewAsset.source_path : ""
                    visible: rootObj.previewAsset && rootObj.previewAsset.type === "screenshot" && !rootObj.previewAsset.deleted
                    asynchronous: true
                }

                // Video Preview (Recordings - Autoplay & Loop & Muted)
                Video {
                    id: previewVideoPlayer

                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Video.PreserveAspectFit
                    source: rootObj.previewAsset && rootObj.previewAsset.type === "recording" && !rootObj.previewAsset.deleted ? "file://" + rootObj.previewAsset.source_path : ""
                    visible: rootObj.previewAsset && rootObj.previewAsset.type === "recording" && !rootObj.previewAsset.deleted
                    loops: MediaPlayer.Infinite
                    volume: 0 // muted
                    onVisibleChanged: {
                        if (visible)
                            previewVideoPlayer.play();
                        else
                            previewVideoPlayer.stop();
                    }
                    Component.onCompleted: {
                        if (visible)
                            previewVideoPlayer.play();
                    }
                }
            }

            // Zoom with mouse wheel
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton // Let mouse events propagate for dragging
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) {
                        previewFlickable.zoomScale = Math.min(5.0, previewFlickable.zoomScale + 0.15);
                    } else {
                        previewFlickable.zoomScale = Math.max(1.0, previewFlickable.zoomScale - 0.15);
                    }
                }
            }

            // Drag to pan and Click to close detection
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                property int startX: 0
                property int startY: 0
                onPressed: function(mouse) {
                    startX = mouse.x;
                    startY = mouse.y;
                    mouse.accepted = false; // Propagate press to Flickable
                }
                onReleased: function(mouse) {
                    var dx = Math.abs(mouse.x - startX);
                    var dy = Math.abs(mouse.y - startY);
                    if (dx < 5 && dy < 5) {
                        rootObj.closePreview();
                    }
                }
            }
        }

        // Close on click if it's OCR Text Preview (which doesn't use the media Flickable)
        MouseArea {
            anchors.fill: parent
            visible: rootObj.previewOcrText !== ""
            onClicked: rootObj.closePreview()
        }

        Text {
            anchors.centerIn: parent
            visible: rootObj.previewAsset && rootObj.previewAsset.deleted
            text: "file missing"
            color: "#fb4934"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 8
        }

        // OCR Text Preview
        Flickable {
            anchors.fill: parent
            anchors.margins: 6
            visible: rootObj.previewOcrText !== ""
            contentHeight: ocrTextPreview.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: ocrTextPreview
                width: parent.width
                text: rootObj.previewOcrText
                color: themeObj.accent
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 8
                wrapMode: Text.Wrap
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle {
                    radius: 2
                    color: themeObj.accent
                    opacity: 0.6
                }
            }
        }
    }
}
