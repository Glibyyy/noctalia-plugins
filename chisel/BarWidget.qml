import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  // --- Injected by shell (all required) ---
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // --- Bar positioning ---
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // --- State from Main.qml ---
  readonly property var mainInstance: pluginApi?.mainInstance
  property string state: mainInstance ? mainInstance.state : "disabled"
  property string connectionInfo: mainInstance ? mainInstance.connectionInfo : ""

  // --- Derived display props ---
  readonly property string icon: {
    switch (state) {
      case "connected": return "circle-check"
      case "waiting": return "circle-dot"
      default: return "circle-x"
    }
  }
  readonly property string label: {
    switch (state) {
      case "connected": return "Connected"
      case "waiting": return "Listening"
      default: return "Off"
    }
  }
  readonly property color iconColor: {
    switch (state) {
      case "connected": return Color.mPrimary
      case "waiting": return Color.mTertiary
      default: return Color.mOnSurfaceVariant
    }
  }
  readonly property color textColor: {
    switch (state) {
      case "disabled": return Color.mOnSurfaceVariant
      default: return Color.mOnSurface
    }
  }
  readonly property string tooltipText: {
    switch (state) {
      case "connected": return "Chisel: " + (connectionInfo || "connected")
      case "waiting": return "Chisel: server running, awaiting client"
      default: return "Chisel: disabled"
    }
  }

  // --- Sizing ---
  property real margins: Style.marginM * 2
  readonly property real contentWidth: isVertical
    ? capsuleHeight
    : Math.round(rowLayout.implicitWidth + margins)
  readonly property real contentHeight: isVertical
    ? Math.round(rowLayout.implicitHeight + margins)
    : capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight
  Layout.alignment: Qt.AlignVCenter

  // --- Capsule ---
  Rectangle {
    id: capsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 4

      NIcon {
        icon: root.icon
        color: root.iconColor
        pointSize: root.barFontSize
      }

      NText {
        text: root.label
        pointSize: root.barFontSize
        color: root.textColor
      }
    }
  }

  // --- Interaction ---
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
      TooltipService.show(
        root,
        root.tooltipText,
        BarService.getTooltipDirection()
      )
    }
    onExited: TooltipService.hide()

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (mainInstance) {
          if (root.state !== "disabled") {
            mainInstance.stopper.running = true
          } else {
            mainInstance.starter.running = true
          }
        }
      } else if (mouse.button === Qt.RightButton) {
        BarService.openPluginSettings(root.screen, pluginApi.manifest)
      }
    }
  }
}
