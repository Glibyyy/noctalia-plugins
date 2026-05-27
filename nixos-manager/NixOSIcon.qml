import QtQuick
import qs.Commons

Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color statusColor: Color.mPrimary
  property bool showStatus: false

  readonly property real iconSize: Math.max(1, applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize)

  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    anchors.fill: parent
    source: "nixos-logo.svg"
    sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
  }

  // Status dot (bottom-right corner)
  Rectangle {
    visible: root.showStatus
    width: root.iconSize * 0.35
    height: root.iconSize * 0.35
    radius: width / 2
    color: root.statusColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
  }
}
