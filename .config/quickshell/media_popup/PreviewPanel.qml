import QtMultimedia
import QtQuick
import QtQuick.Controls
import Quickshell

Rectangle {
    id: previewBg

    property var editorAsset: root.expandedAssetId >= 0 ? root.assetById(root.expandedAssetId) : null

    anchors.fill: parent
    color: theme.popupBgColor
    border.width: 1
    border.color: theme.accent
    radius: 0
    antialiasing: false

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeEditor()
    }

    // Image Preview (Screenshots)
    Image {
        anchors.fill: parent
        anchors.margins: 4
        fillMode: Image.PreserveAspectFit
        source: previewBg.editorAsset && !previewBg.editorAsset.deleted ? "file://" + previewBg.editorAsset.source_path : ""
        visible: previewBg.editorAsset && previewBg.editorAsset.type === "screenshot" && !previewBg.editorAsset.deleted
        asynchronous: true
    }

    // Video Preview (Recordings - Autoplay & Loop & Muted)
    Video {
        id: videoPlayer

        anchors.fill: parent
        anchors.margins: 4
        fillMode: Video.PreserveAspectFit
        source: previewBg.editorAsset && !previewBg.editorAsset.deleted && previewBg.editorAsset.type === "recording" ? "file://" + previewBg.editorAsset.source_path : ""
        visible: previewBg.editorAsset && previewBg.editorAsset.type === "recording" && !previewBg.editorAsset.deleted
        loops: MediaPlayer.Infinite
        volume: 0 // muted
        onVisibleChanged: {
            if (visible)
                videoPlayer.play();
            else
                videoPlayer.stop();
        }
        Component.onCompleted: {
            if (visible)
                videoPlayer.play();

        }
    }

    Text {
        anchors.centerIn: parent
        visible: previewBg.editorAsset && previewBg.editorAsset.deleted
        text: "file missing"
        color: "#fb4934"
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 8
    }

}
